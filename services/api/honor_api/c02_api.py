from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal
from typing import Any
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, Query, Request

from .auth import require_owner
from .c02_finance import cost_summary_from_rows, polli_envelope, summarize_finance, validate_earning_creation
from .c02_rules import CANONICAL_RULE_KEYS, KnowledgeState, validate_owner_url
from .db import owner_transaction
from .errors import HonorError
from .idempotency import canonical_response_hash, request_hash

router = APIRouter(prefix="/v1")


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _require_idempotency(key: str | None) -> str:
    if not key:
        raise HonorError(400, "MISSING_IDEMPOTENCY_KEY", "Idempotency-Key header is required.")
    return key


def _typed(value_type: str, value: Any) -> dict[str, Any]:
    return {"value_type": value_type, "value": value}


async def _record_idempotency(conn, *, owner: str, key: str, method: str, path: str, body: bytes, response: dict[str, Any]):
    existing = await conn.fetchrow(
        "SELECT * FROM api_idempotency_records WHERE owner_user_id=$1::uuid AND idempotency_key=$2",
        owner,
        key,
    )
    req_hash = request_hash(body)
    if existing:
        if existing["request_sha256"] != req_hash or existing["http_method"] != method or existing["path"] != path:
            raise HonorError(409, "IDEMPOTENCY_KEY_REUSED", "Idempotency key reused with different request.")
        return existing["response_body"]
    await conn.execute(
        """
        INSERT INTO api_idempotency_records(
          id,owner_user_id,idempotency_key,http_method,path,request_sha256,
          response_status,response_body,response_sha256,expires_at
        ) VALUES($1,$2::uuid,$3,$4,$5,$6,200,$7,$8,statement_timestamp()+interval '1 day')
        """,
        uuid4(),
        owner,
        key,
        method,
        path,
        req_hash,
        response,
        canonical_response_hash(response),
    )
    return response


def _manual_rule_payload(key: str, value: Any) -> tuple[str, dict[str, Any] | None]:
    if value is None:
        return KnowledgeState.UNKNOWN.value, None
    mapping = {
        "provider": "STRING",
        "campaign_url": "STRING",
        "external_campaign_id": "STRING",
        "status": "CAMPAIGN_STATUS",
        "compensation_model": "COMPENSATION_MODEL",
        "cpm_or_rate": "RATE",
        "minimum_views": "INTEGER",
        "max_payout_per_clip": "MONEY_USD",
        "total_budget": "MONEY_USD",
        "remaining_budget": "MONEY_USD",
        "start_at": "TIMESTAMP",
        "end_at": "TIMESTAMP",
        "deadline_at": "TIMESTAMP",
        "eligible_platforms": "PLATFORMS",
        "eligible_regions": "REGIONS",
        "eligible_account_requirements": "ACCOUNT_REQUIREMENTS",
        "required_tags": "STRING_ARRAY",
        "required_mentions": "STRING_ARRAY",
        "required_hashtags": "STRING_ARRAY",
        "disclosure_requirements": "DISCLOSURE_REQUIREMENTS",
        "source_material_restrictions": "RESTRICTION_SET",
        "clip_length_min_seconds": "DURATION_SECONDS",
        "clip_length_max_seconds": "DURATION_SECONDS",
        "content_restrictions": "RESTRICTION_SET",
        "editing_restrictions": "RESTRICTION_SET",
        "uniqueness_rules": "RESTRICTION_SET",
        "submission_format": "SUBMISSION_FORMAT",
        "analytics_window": "WINDOW",
        "payout_window": "WINDOW",
        "render_audio_rules": "RENDER_AUDIO_RULES",
        "platform_native_audio_rules": "PLATFORM_NATIVE_AUDIO_RULES",
        "last_verified_at": "TIMESTAMP",
    }
    return KnowledgeState.KNOWN.value, _typed(mapping[key], value)


@router.get("/campaigns")
async def list_campaigns(
    owner: str = Depends(require_owner),
    status: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=100),
):
    async with owner_transaction(owner) as conn:
        rows = await conn.fetch(
            """
            SELECT id,provider,campaign_url,external_campaign_id,status,title,terms_snapshot_id,
                   start_at,end_at,deadline_at,last_verified_at,created_at
              FROM campaigns
             WHERE ($1::campaign_status_enum IS NULL OR status=$1::campaign_status_enum)
             ORDER BY created_at DESC,id DESC
             LIMIT $2
            """,
            status,
            limit,
        )
    return {"items": [dict(row) for row in rows], "next_cursor": None}


@router.get("/campaigns/{campaign_id}")
async def get_campaign(campaign_id: str, owner: str = Depends(require_owner)):
    async with owner_transaction(owner) as conn:
        campaign = await conn.fetchrow("SELECT * FROM campaigns WHERE id=$1::uuid", campaign_id)
        if campaign is None:
            raise HonorError(404, "NOT_FOUND", "Campaign not found.")
        rules = await conn.fetch(
            """
            SELECT rule_key,knowledge_state,typed_value,confidence,evidence_snapshot_id,
                   evidence_locator,verified_at,verified_by,terms_snapshot_id
              FROM campaign_rule_items
             WHERE campaign_id=$1::uuid AND terms_snapshot_id=$2::uuid
             ORDER BY rule_key
            """,
            campaign_id,
            campaign["terms_snapshot_id"],
        )
    return {"campaign": dict(campaign), "rules": [dict(row) for row in rules]}


@router.post("/campaigns/import")
async def import_campaign(
    request: Request,
    owner: str = Depends(require_owner),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    key = _require_idempotency(idempotency_key)
    body = await request.json()
    raw_body = await request.body()
    variant = body.get("variant")
    if variant not in {"MANUAL", "OWNER_URL", "OFFICIAL_API"}:
        raise HonorError(400, "INVALID_ARGUMENT", "Unsupported campaign import variant.")
    if variant == "OWNER_URL":
        validate_owner_url(body.get("url", ""))
        raise HonorError(422, "OWNER_EVIDENCE_REQUIRED", "OWNER_URL records locator only; manual evidence is required.")
    if variant == "OFFICIAL_API":
        raise HonorError(501, "PROVIDER_UNAVAILABLE", "No official provider adapter is configured for C02 CI.")
    rules_in = body.get("rules") or {}
    missing = [key for key in CANONICAL_RULE_KEYS if key not in rules_in]
    if missing:
        raise HonorError(400, "INCOMPLETE_RULE_SET", "Manual import requires all 32 canonical rules.", {"missing": missing})
    campaign_id = str(uuid4())
    snapshot_id = str(uuid4())
    provider = rules_in["provider"]
    if provider is None:
        raise HonorError(400, "PROVIDER_UNKNOWN", "provider must be KNOWN before activation.")
    title = body.get("title") or str(provider)
    async with owner_transaction(owner) as conn:
        await conn.execute(
            """
            INSERT INTO campaigns(id,provider,campaign_url,external_campaign_id,status,title)
            VALUES($1,$2,$3,$4,COALESCE($5,'UNKNOWN')::campaign_status_enum,$6)
            """,
            campaign_id,
            str(provider),
            rules_in.get("campaign_url"),
            rules_in.get("external_campaign_id"),
            rules_in.get("status"),
            title,
        )
        await conn.execute(
            """
            INSERT INTO campaign_terms_snapshots(
              id,campaign_id,captured_at,source_url,storage_object_key,sha256,capture_method,notes
            ) VALUES($1,$2,statement_timestamp(),$3,$4,$5,'MANUAL_ENTRY',$6)
            """,
            snapshot_id,
            campaign_id,
            body.get("evidence_locator"),
            f"owner-evidence/campaigns/{campaign_id}/{snapshot_id}",
            body.get("evidence_sha256", "0" * 64),
            body.get("notes"),
        )
        for rule_key in CANONICAL_RULE_KEYS:
            knowledge_state, typed_value = _manual_rule_payload(rule_key, rules_in[rule_key])
            await conn.execute(
                """
                INSERT INTO campaign_rule_items(
                  id,campaign_id,terms_snapshot_id,rule_key,knowledge_state,typed_value,
                  confidence,evidence_snapshot_id,evidence_locator,verified_at,verified_by
                ) VALUES($1,$2,$3,$4,$5::knowledge_state_enum,$6,$7,$3,$8,statement_timestamp(),'OWNER_MANUAL')
                """,
                uuid4(),
                campaign_id,
                snapshot_id,
                rule_key,
                knowledge_state,
                typed_value,
                Decimal("1.000") if knowledge_state == "KNOWN" else None,
                body.get("evidence_locator"),
            )
        rules_sha = await conn.fetchval("SELECT honor_seal_campaign_rule_set($1::uuid,$2::uuid,1)", campaign_id, snapshot_id)
        await conn.fetchval("SELECT honor_activate_campaign_rule_snapshot($1::uuid,$2::uuid)", campaign_id, snapshot_id)
        response = {"campaign_id": campaign_id, "terms_snapshot_id": snapshot_id, "rules_sha256": rules_sha}
        return await _record_idempotency(conn, owner=owner, key=key, method="POST", path="/v1/campaigns/import", body=raw_body, response=response)


@router.get("/finance/summary")
async def finance_summary(owner: str = Depends(require_owner)):
    async with owner_transaction(owner) as conn:
        earnings = [dict(row) for row in await conn.fetch("SELECT state,amount_usd FROM earnings")]
        costs = [dict(row) for row in await conn.fetch("SELECT service,unit,estimated_cost_usd,actual_cost_usd FROM cost_ledger")]
    return summarize_finance(earnings, costs).to_dict()


@router.get("/costs/summary")
async def costs_summary(owner: str = Depends(require_owner)):
    async with owner_transaction(owner) as conn:
        rows = [dict(row) for row in await conn.fetch("SELECT service,unit,estimated_cost_usd,actual_cost_usd FROM cost_ledger")]
    return cost_summary_from_rows(rows)


@router.post("/payout-events")
async def payout_events(
    request: Request,
    owner: str = Depends(require_owner),
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
):
    key = _require_idempotency(idempotency_key)
    body = await request.json()
    raw_body = await request.body()
    validate_earning_creation(body.get("state"))
    earning_id = str(uuid4())
    async with owner_transaction(owner) as conn:
        await conn.execute(
            """
            INSERT INTO earnings(
              id,campaign_id,rule_snapshot_id,post_id,external_earning_id,amount_usd,
              state,recognized_at,last_state_at,evidence_snapshot_id,source,idempotency_key
            ) VALUES($1,$2::uuid,$3::uuid,$4::uuid,$5,$6,'ACCRUED_UNVERIFIED',
              COALESCE($7::timestamptz,statement_timestamp()),statement_timestamp(),
              $8::uuid,COALESCE($9,'OWNER_MANUAL'),$10)
            """,
            earning_id,
            body["campaign_id"],
            body["rule_snapshot_id"],
            body.get("post_id"),
            body.get("external_earning_id"),
            Decimal(str(body["amount_usd"])),
            body.get("recognized_at"),
            body.get("evidence_snapshot_id"),
            body.get("source"),
            key,
        )
        response = {"earning_id": earning_id, "state": "ACCRUED_UNVERIFIED"}
        return await _record_idempotency(conn, owner=owner, key=key, method="POST", path="/v1/payout-events", body=raw_body, response=response)


def build_c02_polli_gateway_handlers(conn):
    async def finance(_args):
        earnings = [dict(row) for row in await conn.fetch("SELECT state,amount_usd FROM earnings")]
        costs = [dict(row) for row in await conn.fetch("SELECT service,unit,estimated_cost_usd,actual_cost_usd FROM cost_ledger")]
        return polli_envelope("finance_summary", summarize_finance(earnings, costs).to_dict())

    async def costs(_args):
        rows = [dict(row) for row in await conn.fetch("SELECT service,unit,estimated_cost_usd,actual_cost_usd FROM cost_ledger")]
        return polli_envelope("cost_summary", cost_summary_from_rows(rows))

    return {"finance_summary": finance, "cost_summary": costs}
