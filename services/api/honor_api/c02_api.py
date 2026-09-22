from __future__ import annotations

import base64
import hashlib
import json
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any
from uuid import UUID, uuid4

from fastapi import APIRouter, Depends, Header, Query, Request
from fastapi.responses import JSONResponse

from .auth import require_owner
from .c02_contracts import validate as validate_contract
from .c02_finance import cost_summary_from_rows, polli_envelope, summarize_finance
from .c02_rules import CANONICAL_RULE_KEYS, KnowledgeState, validate_owner_url
from .db import owner_transaction
from .errors import HonorError
from .idempotency import canonical_response_hash, request_hash
from .jobs import DurableJobStore, JobSpec
from .storage import safe_key, storage

router = APIRouter(prefix="/v1")


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _iso(value: Any) -> str | None:
    return value.isoformat() if hasattr(value, "isoformat") else value


def _require_idempotency(key: str | None) -> str:
    if not key:
        raise HonorError(422, "IDEMPOTENCY_KEY_REQUIRED", "Idempotency-Key header is required.")
    if len(key) > 255:
        raise HonorError(422, "VALIDATION_ERROR", "Idempotency-Key is too long.")
    return key


async def _preflight(conn, *, owner: str, key: str, method: str, path: str, body: bytes):
    await conn.execute("SELECT pg_advisory_xact_lock(hashtextextended($1,0))", f"{owner}:{key}")
    row = await conn.fetchrow(
        "SELECT response_status,response_body,request_sha256,http_method,path FROM api_idempotency_records WHERE owner_user_id=$1::uuid AND idempotency_key=$2",
        owner, key,
    )
    if row is None:
        return None
    if row["request_sha256"] != request_hash(body) or row["http_method"] != method or row["path"] != path:
        raise HonorError(409, "IDEMPOTENCY_KEY_REUSED", "Idempotency key reused with different request.")
    return JSONResponse(status_code=row["response_status"], content=dict(row["response_body"]))


async def _store_response(conn, *, owner: str, key: str, method: str, path: str, body: bytes, status: int, response: dict[str, Any]):
    await conn.execute(
        """INSERT INTO api_idempotency_records(
             id,owner_user_id,idempotency_key,http_method,path,request_sha256,
             response_status,response_body,expires_at
           ) VALUES($1,$2::uuid,$3,$4,$5,$6,$7,$8,statement_timestamp()+interval '1 day')""",
        uuid4(), owner, key, method, path, request_hash(body), status, response,
    )
    return response


async def _validated_body(request: Request, schema: str) -> tuple[dict[str, Any], bytes]:
    raw = await request.body()
    try:
        body = json.loads(raw)
        validate_contract(schema, body)
    except (json.JSONDecodeError, ValueError, TypeError) as exc:
        raise HonorError(422, "VALIDATION_ERROR", "Request validation failed.") from exc
    return body, raw


def _cursor_encode(created_at: Any, row_id: Any) -> str:
    return base64.urlsafe_b64encode(f"{_iso(created_at)}|{row_id}".encode()).decode().rstrip("=")


def _cursor_decode(cursor: str | None) -> tuple[str, str] | None:
    if not cursor:
        return None
    try:
        raw = base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)).decode()
        created, row_id = raw.split("|", 1)
        UUID(row_id)
        return created, row_id
    except Exception as exc:
        raise HonorError(422, "VALIDATION_ERROR", "Invalid cursor.") from exc


def _campaign_summary(row: Any) -> dict[str, Any]:
    return {"id": str(row["id"]), "provider": str(row["provider"]), "campaign_url": row["campaign_url"], "external_campaign_id": row["external_campaign_id"], "status": str(row["status"]), "title": row["title"], "currency": str(row.get("currency") or "USD"), "start_at": _iso(row.get("start_at")), "end_at": _iso(row.get("end_at")), "deadline_at": _iso(row.get("deadline_at")), "last_verified_at": _iso(row.get("last_verified_at"))}


def _rule_record(row: Any) -> dict[str, Any]:
    return {"rule_snapshot_id": str(row["terms_snapshot_id"]), "rule_key": row["rule_key"], "knowledge_state": str(row["knowledge_state"]), "typed_value": row["typed_value"], "confidence": float(row["confidence"]) if row["confidence"] is not None else None, "evidence_snapshot_id": str(row["evidence_snapshot_id"]) if row["evidence_snapshot_id"] else None, "evidence_locator": row["evidence_locator"], "verified_at": _iso(row["verified_at"]), "verified_by": str(row["verified_by"]), "schema_version": int(row["schema_version"])}


@router.get("/campaigns")
async def list_campaigns(owner: str = Depends(require_owner), status: str | None = Query(default=None), limit: int = Query(default=50, ge=1, le=100), cursor: str | None = Query(default=None)):
    decoded = _cursor_decode(cursor)
    async with owner_transaction(owner) as conn:
        rows = await conn.fetch("""SELECT id,provider,campaign_url,external_campaign_id,status,title,currency,start_at,end_at,deadline_at,last_verified_at,created_at FROM campaigns WHERE ($1::campaign_status_enum IS NULL OR status=$1::campaign_status_enum) AND ($2::timestamptz IS NULL OR (created_at,id)<($2::timestamptz,$3::uuid)) ORDER BY created_at DESC,id DESC LIMIT $4""", status, decoded[0] if decoded else None, decoded[1] if decoded else None, limit + 1)
    has_more = len(rows) > limit; page_rows = rows[:limit]; next_cursor = _cursor_encode(page_rows[-1]["created_at"], page_rows[-1]["id"]) if has_more else None
    response = {"items": [_campaign_summary(row) for row in page_rows], "page": {"next_cursor": next_cursor, "limit": limit, "has_more": has_more}}
    validate_contract("CampaignList", response); return response


@router.get("/campaigns/{campaign_id}")
async def get_campaign(campaign_id: str, owner: str = Depends(require_owner)):
    try: UUID(campaign_id)
    except ValueError as exc: raise HonorError(422, "VALIDATION_ERROR", "campaign id must be a UUID.") from exc
    async with owner_transaction(owner) as conn:
        campaign = await conn.fetchrow("SELECT * FROM campaigns WHERE id=$1::uuid", campaign_id)
        if campaign is None: raise HonorError(404, "NOT_FOUND", "Campaign not found.")
        rules = await conn.fetch("SELECT rule_key,knowledge_state,typed_value,confidence,evidence_snapshot_id,evidence_locator,verified_at,verified_by,terms_snapshot_id,schema_version FROM campaign_rule_items WHERE campaign_id=$1::uuid AND terms_snapshot_id=$2::uuid ORDER BY rule_key", campaign_id, campaign["terms_snapshot_id"])
    response = {"campaign": _campaign_summary(campaign), "terms_snapshot_id": str(campaign["terms_snapshot_id"]) if campaign["terms_snapshot_id"] else None, "rules": [_rule_record(row) for row in rules]}; validate_contract("CampaignDetail", response); return response


def _manual_rules(body: dict[str, Any]) -> list[tuple[str, str, dict[str, Any] | None]]:
    values: dict[str, dict[str, Any]] = {"provider": {"value_type": "STRING", "value": body["provider"]}, "status": {"value_type": "CAMPAIGN_STATUS", "value": "VERIFYING"}}
    if body.get("campaign_url"): values["campaign_url"] = {"value_type": "STRING", "value": body["campaign_url"]}
    if body.get("external_campaign_id"): values["external_campaign_id"] = {"value_type": "STRING", "value": body["external_campaign_id"]}
    return [(key, KnowledgeState.KNOWN.value if key in values else KnowledgeState.UNKNOWN.value, values.get(key)) for key in CANONICAL_RULE_KEYS]


@router.post("/campaigns/import", status_code=202)
async def import_campaign(request: Request, owner: str = Depends(require_owner), idempotency_key: str | None = Header(default=None, alias="Idempotency-Key")):
    key = _require_idempotency(idempotency_key); body, raw_body = await _validated_body(request, "CampaignImportRequest"); method = body["method"]
    if method == "OWNER_URL":
        try: validate_owner_url(body["campaign_url"])
        except ValueError as exc: raise HonorError(422, "VALIDATION_ERROR", str(exc)) from exc
    if method == "OFFICIAL_API": raise HonorError(503, "PROVIDER_UNAVAILABLE", "No official provider adapter is configured.")
    campaign_id, snapshot_id, correlation_id = str(uuid4()), str(uuid4()), str(uuid4())
    async with owner_transaction(owner) as conn:
        replay = await _preflight(conn, owner=owner, key=key, method="POST", path="/v1/campaigns/import", body=raw_body)
        if replay is not None: return replay
        await conn.execute("INSERT INTO campaigns(id,provider,campaign_url,external_campaign_id,status,title,currency) VALUES($1::uuid,$2,$3,$4,'VERIFYING',$5,'USD')", campaign_id, body["provider"], body.get("campaign_url"), body.get("external_campaign_id"), body.get("title") or body["provider"])
        terms_upload = None
        if body.get("terms_upload_id"):
            terms_upload = await conn.fetchrow("SELECT object_key,expected_sha256,state FROM uploads WHERE id=$1::uuid AND owner_user_id=$2::uuid", body["terms_upload_id"], owner)
            if terms_upload is None or str(terms_upload["state"]) != "VERIFIED":
                raise HonorError(409, "CONFLICT", "Campaign terms upload is not verified.")
        terms_text = body.get("terms_text") or f"OWNER_IMPORT:{body['provider']}:{body.get('external_campaign_id') or ''}"; digest = hashlib.sha256(terms_text.encode()).hexdigest()
        snapshot_key = terms_upload["object_key"] if terms_upload else f"evidence/campaigns/{campaign_id}/{snapshot_id}.terms"
        snapshot_sha = terms_upload["expected_sha256"] if terms_upload else digest
        capture_method = "OWNER_UPLOAD" if terms_upload else ("PERMITTED_PAGE" if method == "OWNER_URL" else "MANUAL_ENTRY")
        await conn.execute("INSERT INTO campaign_terms_snapshots(id,campaign_id,captured_at,source_url,storage_object_key,sha256,capture_method,notes) VALUES($1::uuid,$2::uuid,statement_timestamp(),$3,$4,$5,$6::capture_method_enum,$7)", snapshot_id, campaign_id, body.get("campaign_url"), snapshot_key, snapshot_sha, capture_method, "deterministic C02 fixture normalization")
        for rule_key, state, typed in _manual_rules(body):
            await conn.execute("INSERT INTO campaign_rule_items(id,campaign_id,terms_snapshot_id,rule_key,knowledge_state,typed_value,confidence,evidence_snapshot_id,evidence_locator,verified_at,verified_by) VALUES($1,$2::uuid,$3::uuid,$4,$5::knowledge_state_enum,$6,$7,$3::uuid,$8,statement_timestamp(),'OWNER')", uuid4(), campaign_id, snapshot_id, rule_key, state, typed, Decimal("1.000") if state == "KNOWN" else None, body.get("campaign_url"))
        await conn.fetchval("SELECT honor_seal_campaign_rule_set($1::uuid,$2::uuid,1)", campaign_id, snapshot_id); await conn.fetchval("SELECT honor_activate_campaign_rule_snapshot($1::uuid,$2::uuid)", campaign_id, snapshot_id)
    job = await DurableJobStore().enqueue_and_dispatch(owner, JobSpec("campaign_import", "campaign", campaign_id, "campaign_import", f"campaign-import:{key}", correlation_id), event_name="CAMPAIGN_DISCOVERED", event_payload={"event_name":"CAMPAIGN_DISCOVERED","subject_type":"campaign","subject_id":campaign_id,"state":"VERIFYING","reason_code":None,"evidence_id":snapshot_id,"amount_usd":None,"related_ids":[]})
    response = {"campaign_id": campaign_id, "job_id": job.id, "status": "VERIFYING", "correlation_id": correlation_id}; validate_contract("CampaignImportAccepted", response)
    async with owner_transaction(owner) as conn:
        await conn.execute("SELECT pg_advisory_xact_lock(hashtextextended($1,0))", f"{owner}:{key}"); await _store_response(conn, owner=owner, key=key, method="POST", path="/v1/campaigns/import", body=raw_body, status=202, response=response)
    return response


def _source_record(row: Any, eligibility: str = "UNKNOWN") -> dict[str, Any]:
    return {"id": str(row["id"]), "origin_type": str(row["origin_type"]), "source_url": row["source_url"], "provider": row["provider"], "external_source_id": row["external_source_id"], "title": row["title"], "sha256": row["sha256"], "duration_ms": row["duration_ms"], "ingest_status": str(row["ingest_status"]), "eligibility": eligibility, "created_at": _iso(row["created_at"]), "updated_at": _iso(row["updated_at"])}


@router.post("/sources/import", status_code=202)
async def import_source(request: Request, owner: str = Depends(require_owner), idempotency_key: str | None = Header(default=None, alias="Idempotency-Key")):
    key = _require_idempotency(idempotency_key); body, raw_body = await _validated_body(request, "SourceImportRequest"); rights = body["rights"]
    if body["method"] == "OWNER_URL":
        try: validate_owner_url(body["source_url"])
        except ValueError as exc: raise HonorError(422, "VALIDATION_ERROR", str(exc)) from exc
    source_id, correlation_id = str(uuid4()), str(uuid4()); ingest = "PENDING_UPLOAD" if body["method"] == "MANUAL_UPLOAD" else "QUEUED"
    if rights["eligibility"] != "ELIGIBLE": ingest = "BLOCKED_RIGHTS"
    async with owner_transaction(owner) as conn:
        replay = await _preflight(conn, owner=owner, key=key, method="POST", path="/v1/sources/import", body=raw_body)
        if replay is not None: return replay
        await conn.execute("INSERT INTO sources(id,origin_type,source_url,provider,external_source_id,title,ingest_status) VALUES($1::uuid,$2::source_origin_enum,$3,$4,$5,$6,$7::source_ingest_status_enum)", source_id, body["origin_type"], body.get("source_url"), body["provider"], body.get("external_source_id"), body.get("title"), ingest)
        upload_id, evidence_uri = rights.get("evidence_upload_id"), rights.get("evidence_url"); evidence_object = None
        if upload_id:
            upload = await conn.fetchrow("SELECT object_key,state FROM uploads WHERE id=$1::uuid AND owner_user_id=$2::uuid", upload_id, owner)
            if upload is None or str(upload["state"]) != "VERIFIED": raise HonorError(409, "CONFLICT", "Rights evidence upload is not verified.")
            evidence_object = upload["object_key"]
        record_hash = hashlib.sha256(json.dumps({"source_id":source_id,"rights":rights}, sort_keys=True).encode()).hexdigest()
        await conn.fetchval("SELECT honor_commit_source_rights_version($1::uuid,$2::uuid,1,NULL,$3::source_eligibility_enum,$4::jsonb,$5::jsonb,$6,$7,$8,statement_timestamp(),$9::timestamptz,$10,$11,$12::uuid[])", uuid4(), source_id, rights["eligibility"], json.dumps(rights["authorized_uses"]), json.dumps(rights["platform_limits"]), rights["evidence_type"], evidence_uri, evidence_object, rights.get("expires_at"), None, record_hash, [body["campaign_id"]])
    event_name = "SOURCE_ELIGIBILITY_VERIFIED" if rights["eligibility"] == "ELIGIBLE" else "CAMPAIGN_RULES_BLOCKED_UNKNOWN"
    job = await DurableJobStore().enqueue_and_dispatch(owner, JobSpec("source_import", "source", source_id, "source_ingest", f"source-import:{key}", correlation_id), event_name=event_name, event_payload={"event_name":event_name,"subject_type":"source","subject_id":source_id,"state":ingest,"reason_code":None,"evidence_id":None,"amount_usd":None,"related_ids":[body["campaign_id"]]})
    response = {"source_id":source_id,"job_id":job.id,"ingest_status":ingest,"correlation_id":correlation_id}; validate_contract("SourceImportAccepted", response)
    async with owner_transaction(owner) as conn:
        await conn.execute("SELECT pg_advisory_xact_lock(hashtextextended($1,0))", f"{owner}:{key}"); await _store_response(conn, owner=owner, key=key, method="POST", path="/v1/sources/import", body=raw_body, status=202, response=response)
    return response


@router.get("/sources/{source_id}")
async def get_source(source_id: str, owner: str = Depends(require_owner)):
    async with owner_transaction(owner) as conn: row = await conn.fetchrow("SELECT s.*,COALESCE((SELECT eligibility::text FROM source_rights r WHERE r.source_id=s.id ORDER BY rights_version DESC LIMIT 1),'UNKNOWN') eligibility FROM sources s WHERE s.id=$1::uuid", source_id)
    if row is None: raise HonorError(404, "NOT_FOUND", "Source not found.")
    result = _source_record(row, row["eligibility"]); validate_contract("SourceRecord", result); return result


@router.post("/uploads/intents", status_code=201)
async def create_upload_intent(request: Request, owner: str = Depends(require_owner), idempotency_key: str | None = Header(default=None, alias="Idempotency-Key")):
    key = _require_idempotency(idempotency_key); body, raw = await _validated_body(request, "UploadIntentRequest"); upload_id = str(uuid4()); expires = _now() + timedelta(hours=1); object_key = safe_key("uploads/", f"{owner}/{upload_id}/{body['filename']}")
    async with owner_transaction(owner) as conn:
        replay = await _preflight(conn, owner=owner, key=key, method="POST", path="/v1/uploads/intents", body=raw)
        if replay is not None: return replay
        await conn.execute("INSERT INTO uploads(id,owner_user_id,purpose,filename,content_type,object_key,expected_size_bytes,expected_sha256,expires_at) VALUES($1::uuid,$2::uuid,$3::upload_purpose_enum,$4,$5,$6,$7,$8,$9)", upload_id, owner, body["purpose"], body["filename"], body["content_type"], object_key, body["size_bytes"], body["sha256"], expires)
        response = {"upload_id":upload_id,"state":"INTENT_CREATED","method":"PUT","upload_url":storage().presign_put(object_key,3600,body["content_type"]),"required_headers":{"Content-Type":body["content_type"],"x-honor-sha256":body["sha256"]},"expires_at":expires.isoformat()}; validate_contract("UploadIntentResponse", response); await _store_response(conn, owner=owner, key=key, method="POST", path="/v1/uploads/intents", body=raw, status=201, response=response); return response


@router.post("/uploads/{upload_id}/complete")
async def complete_upload(upload_id: str, request: Request, owner: str = Depends(require_owner), idempotency_key: str | None = Header(default=None, alias="Idempotency-Key")):
    key = _require_idempotency(idempotency_key); body, raw = await _validated_body(request, "UploadCompleteRequest")
    async with owner_transaction(owner) as conn:
        replay = await _preflight(conn, owner=owner, key=key, method="POST", path=f"/v1/uploads/{upload_id}/complete", body=raw)
        if replay is not None: return replay
        row = await conn.fetchrow("SELECT * FROM uploads WHERE id=$1::uuid AND owner_user_id=$2::uuid FOR UPDATE", upload_id, owner)
        if row is None: raise HonorError(404, "UPLOAD_NOT_FOUND", "Upload not found.")
        if row["expires_at"] <= _now(): await conn.execute("UPDATE uploads SET state='EXPIRED',updated_at=statement_timestamp() WHERE id=$1::uuid", upload_id); raise HonorError(409, "UPLOAD_EXPIRED", "Upload intent expired.")
        if body["size_bytes"] != row["expected_size_bytes"] or body["sha256"] != row["expected_sha256"]: raise HonorError(409, "UPLOAD_MISMATCH", "Upload verification does not match intent.")
        try: data = storage().get(row["object_key"])
        except Exception as exc: raise HonorError(409, "UPLOAD_MISMATCH", "Upload object is unavailable.") from exc
        digest = hashlib.sha256(data).hexdigest()
        if len(data) != body["size_bytes"] or digest != body["sha256"]: raise HonorError(409, "UPLOAD_MISMATCH", "Upload verification failed.")
        await conn.execute("UPDATE uploads SET state='VERIFIED',verified_size_bytes=$2,verified_sha256=$3,verified_at=statement_timestamp(),updated_at=statement_timestamp() WHERE id=$1::uuid", upload_id, len(data), digest); row = await conn.fetchrow("SELECT * FROM uploads WHERE id=$1::uuid", upload_id)
        response = {"id":str(row["id"]),"purpose":str(row["purpose"]),"state":str(row["state"]),"filename":row["filename"],"content_type":row["content_type"],"size_bytes":row["verified_size_bytes"],"sha256":row["verified_sha256"],"expires_at":_iso(row["expires_at"]),"verified_at":_iso(row["verified_at"])}; validate_contract("UploadRecord", response); await _store_response(conn, owner=owner, key=key, method="POST", path=f"/v1/uploads/{upload_id}/complete", body=raw, status=200, response=response); return response


@router.post("/submissions", status_code=201)
async def record_submission(request: Request, owner: str = Depends(require_owner), idempotency_key: str | None = Header(default=None, alias="Idempotency-Key")):
    key = _require_idempotency(idempotency_key); body, raw = await _validated_body(request, "SubmissionRequest")
    async with owner_transaction(owner) as conn:
        replay = await _preflight(conn, owner=owner, key=key, method="POST", path="/v1/submissions", body=raw)
        if replay is not None: return replay
        lineage = await conn.fetchrow("SELECT c.campaign_id FROM posts p JOIN clips c ON c.id=p.clip_id WHERE p.id=$1::uuid", body["post_id"])
        if lineage is None: raise HonorError(404, "NOT_FOUND", "Post not found.")
        if str(lineage["campaign_id"]) != body["campaign_id"]: raise HonorError(409, "CONFLICT", "Submission campaign does not match post lineage.")
        sid = str(uuid4()); await conn.execute("INSERT INTO submissions(id,campaign_id,post_id,submitted_at,submission_reference,status,evidence_object_key,idempotency_key) VALUES($1::uuid,$2::uuid,$3::uuid,$4,$5,$6::submission_status_enum,(SELECT object_key FROM uploads WHERE id=$7::uuid AND owner_user_id=$8::uuid),$9)", sid, body["campaign_id"], body["post_id"], body["submitted_at"], body["submission_reference"], body["status"], body["evidence_upload_id"], owner, key)
        row = await conn.fetchrow("SELECT * FROM submissions WHERE id=$1::uuid", sid); response = {"id":sid,"campaign_id":str(row["campaign_id"]),"post_id":str(row["post_id"]),"submitted_at":_iso(row["submitted_at"]),"submission_reference":row["submission_reference"],"status":str(row["status"]),"created_at":_iso(row["created_at"]),"updated_at":_iso(row["updated_at"])}; validate_contract("SubmissionRecord", response); await _store_response(conn, owner=owner, key=key, method="POST", path="/v1/submissions", body=raw, status=201, response=response); return response


def _analytics_observation(row: Any) -> dict[str, Any]:
    return {"id":str(row["id"]),"post_id":str(row["post_id"]),"checkin_id":str(row["checkin_id"]) if row["checkin_id"] else None,"observed_at":_iso(row["observed_at"]),"views":row["views"],"qualified_views":row["qualified_views"],"likes":row["likes"],"comments":row["comments"],"shares":row["shares"],"saves":row["saves"],"watch_time_ms":row["watch_time_ms"],"average_watch_duration_ms":row["average_watch_duration_ms"],"completed_views":row["completed_views"],"completion_rate_ppm":row["completion_rate_ppm"],"follower_delta":row["follower_delta"],"avg_watch_pct":float(row["avg_watch_pct"]) if row["avg_watch_pct"] is not None else None,"evidence_method":str(row["evidence_method"]),"created_at":_iso(row["created_at"])}


@router.get("/analytics/due")
async def list_due_analytics(owner: str = Depends(require_owner), limit: int = Query(default=50, ge=1, le=100)):
    async with owner_transaction(owner) as conn: rows = await conn.fetch("SELECT * FROM analytics_checkins WHERE status IN ('DUE','MISSED') AND due_at<=statement_timestamp() ORDER BY due_at,id LIMIT $1", limit)
    items = [{"id":str(r["id"]),"post_id":str(r["post_id"]),"checkin_type":str(r["checkin_type"]),"due_at":_iso(r["due_at"]),"completed_at":_iso(r["completed_at"]),"status":str(r["status"]),"created_at":_iso(r["created_at"]),"updated_at":_iso(r["updated_at"])} for r in rows]; result = {"items":items,"page":{"next_cursor":None,"limit":limit,"has_more":False}}; validate_contract("AnalyticsDueList", result); return result


@router.post("/analytics/check-ins", status_code=201)
async def record_analytics_checkin(request: Request, owner: str = Depends(require_owner), idempotency_key: str | None = Header(default=None, alias="Idempotency-Key")):
    key = _require_idempotency(idempotency_key); body, raw = await _validated_body(request, "AnalyticsObservationInput")
    async with owner_transaction(owner) as conn:
        replay = await _preflight(conn, owner=owner, key=key, method="POST", path="/v1/analytics/check-ins", body=raw)
        if replay is not None: return replay
        if await conn.fetchrow("SELECT id FROM posts WHERE id=$1::uuid", body["post_id"]) is None: raise HonorError(404, "NOT_FOUND", "Post not found.")
        checkin = None
        if body["checkin_id"]:
            checkin = await conn.fetchrow("SELECT * FROM analytics_checkins WHERE id=$1::uuid AND post_id=$2::uuid FOR UPDATE", body["checkin_id"], body["post_id"])
            if checkin is None: raise HonorError(409, "CONFLICT", "Check-in does not belong to post.")
            if str(checkin["status"]) not in {"DUE", "MISSED"}: raise HonorError(409, "CONFLICT", "Check-in is not in a completable state.")
        oid = str(uuid4()); await conn.execute("INSERT INTO analytics_observations(id,post_id,observed_at,checkin_id,views,qualified_views,likes,comments,shares,saves,watch_time_ms,average_watch_duration_ms,completed_views,completion_rate_ppm,follower_delta,avg_watch_pct,evidence_method,raw_payload_object_key) VALUES($1::uuid,$2::uuid,$3,$4::uuid,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17::analytics_evidence_method_enum,(SELECT object_key FROM uploads WHERE id=$18::uuid AND owner_user_id=$19::uuid))", oid, body["post_id"], body["observed_at"], body["checkin_id"], body["views"], body["qualified_views"], body["likes"], body["comments"], body["shares"], body["saves"], body["watch_time_ms"], body["average_watch_duration_ms"], body["completed_views"], body["completion_rate_ppm"], body["follower_delta"], body["avg_watch_pct"], body["evidence_method"], body["evidence_upload_id"], owner)
        if checkin is not None: await conn.execute("UPDATE analytics_checkins SET status='COMPLETED',completed_at=statement_timestamp(),updated_at=statement_timestamp() WHERE id=$1::uuid", body["checkin_id"])
        obs = await conn.fetchrow("SELECT * FROM analytics_observations WHERE id=$1::uuid", oid); response = {"observation":_analytics_observation(obs),"checkin":None}
        if checkin is not None:
            current = await conn.fetchrow("SELECT * FROM analytics_checkins WHERE id=$1::uuid", body["checkin_id"]); response["checkin"] = {"id":str(current["id"]),"post_id":str(current["post_id"]),"checkin_type":str(current["checkin_type"]),"due_at":_iso(current["due_at"]),"completed_at":_iso(current["completed_at"]),"status":str(current["status"]),"created_at":_iso(current["created_at"]),"updated_at":_iso(current["updated_at"])}
        validate_contract("AnalyticsCheckinResult", response); await _store_response(conn, owner=owner, key=key, method="POST", path="/v1/analytics/check-ins", body=raw, status=201, response=response); return response


def _earning_record(row: Any) -> dict[str, Any]:
    return {"id":str(row["id"]),"campaign_id":str(row["campaign_id"]),"rule_snapshot_id":str(row["rule_snapshot_id"]),"post_id":str(row["post_id"]) if row["post_id"] else None,"external_earning_id":row["external_earning_id"],"amount_usd":f"{Decimal(row['amount_usd']):.6f}","state":str(row["state"]),"recognized_at":_iso(row["recognized_at"]),"last_state_at":_iso(row["last_state_at"]),"source":row["source"]}


@router.post("/payout-events", status_code=201)
async def payout_events(request: Request, owner: str = Depends(require_owner), idempotency_key: str | None = Header(default=None, alias="Idempotency-Key")):
    key = _require_idempotency(idempotency_key); body, raw = await _validated_body(request, "PayoutEventRequest")
    async with owner_transaction(owner) as conn:
        replay = await _preflight(conn, owner=owner, key=key, method="POST", path="/v1/payout-events", body=raw)
        if replay is not None: return replay
        if body["event_kind"] == "CREATE":
            loc = body["earning_locator"]; campaign = await conn.fetchrow("SELECT terms_snapshot_id FROM campaigns WHERE id=$1::uuid", loc["campaign_id"])
            if campaign is None: raise HonorError(404, "NOT_FOUND", "Campaign not found.")
            if loc["post_id"]:
                lineage = await conn.fetchrow("SELECT c.campaign_id FROM posts p JOIN clips c ON c.id=p.clip_id WHERE p.id=$1::uuid", loc["post_id"])
                if lineage is None or str(lineage["campaign_id"]) != loc["campaign_id"]: raise HonorError(409, "CONFLICT", "Earning post lineage mismatch.")
            eid = str(uuid4()); await conn.execute("INSERT INTO earnings(id,campaign_id,rule_snapshot_id,post_id,external_earning_id,amount_usd,state,recognized_at,last_state_at,evidence_snapshot_id,source,idempotency_key) VALUES($1::uuid,$2::uuid,$3::uuid,$4::uuid,$5,$6,'ACCRUED_UNVERIFIED',$7,$7,$8::uuid,$9,$10)", eid, loc["campaign_id"], campaign["terms_snapshot_id"], loc["post_id"], loc["external_earning_id"], Decimal(body["amount_usd"]), body["occurred_at"], body["evidence_snapshot_id"], body["source"], key)
        else:
            row = await conn.fetchrow("SELECT * FROM earnings WHERE id=$1::uuid FOR UPDATE", body["earning_id"])
            if row is None: raise HonorError(404, "NOT_FOUND", "Earning not found.")
            evidence_uri, evidence_object = None, None
            if body.get("evidence_snapshot_id"):
                evidence = await conn.fetchrow("SELECT source_url,storage_object_key FROM campaign_terms_snapshots WHERE id=$1::uuid AND campaign_id=$2::uuid", body["evidence_snapshot_id"], row["campaign_id"])
                if evidence is None: raise HonorError(409, "CONFLICT", "Evidence snapshot does not belong to earning campaign.")
                evidence_uri, evidence_object = evidence["source_url"], evidence["storage_object_key"]
            if evidence_uri is None and evidence_object is None:
                raise HonorError(422, "VALIDATION_ERROR", "Transition evidence is required.")
            try: await conn.fetchval("SELECT honor_transition_earning($1::uuid,$2::earning_state_enum,$3::timestamptz,$4,$5,$6,$7)", body["earning_id"], body["to_state"], body["occurred_at"], evidence_uri, evidence_object, owner, key)
            except Exception as exc: raise HonorError(409, "CONFLICT", "Invalid earning transition.") from exc
            eid = body["earning_id"]
        result = await conn.fetchrow("SELECT * FROM earnings WHERE id=$1::uuid", eid); response = _earning_record(result); validate_contract("EarningRecord", response); await _store_response(conn, owner=owner, key=key, method="POST", path="/v1/payout-events", body=raw, status=201, response=response); return response


@router.get("/finance/summary")
async def finance_summary(owner: str = Depends(require_owner), as_of: datetime | None = Query(default=None)):
    cutoff = as_of or _now()
    month_start = cutoff.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    async with owner_transaction(owner) as conn:
        earnings = [dict(row) for row in await conn.fetch("SELECT state,amount_usd,recognized_at FROM earnings WHERE recognized_at <= $1", cutoff)]
        costs = [dict(row) for row in await conn.fetch("SELECT service,cost_category,estimated_cost_usd,actual_cost_usd,unit,reconciled_at,external_usage_id,incurred_at FROM cost_ledger WHERE incurred_at <= $1", cutoff)]
    result = summarize_finance(earnings, costs, as_of=cutoff, period_start=month_start).to_openapi_dict(); validate_contract("FinanceSummary", result); return result


@router.get("/costs/summary")
async def costs_summary(owner: str = Depends(require_owner), month: str | None = Query(default=None, pattern=r"^[0-9]{4}-[0-9]{2}$")):
    if month is None:
        month = _now().strftime("%Y-%m")
    try:
        month_start = datetime.strptime(month, "%Y-%m").replace(tzinfo=timezone.utc)
    except ValueError as exc:
        raise HonorError(422, "VALIDATION_ERROR", "month must be YYYY-MM") from exc
    month_end = (month_start.replace(day=28) + timedelta(days=4)).replace(day=1)
    async with owner_transaction(owner) as conn: rows = [dict(row) for row in await conn.fetch("SELECT provider,service,cost_category,estimated_cost_usd,actual_cost_usd,unit,reconciled_at,external_usage_id,incurred_at FROM cost_ledger WHERE incurred_at >= $1 AND incurred_at < $2", month_start, month_end)]
    result = cost_summary_from_rows(rows, month=month); validate_contract("CostSummary", result); return result


def build_c02_polli_gateway_handlers(conn):
    async def finance(_args):
        earnings = [dict(row) for row in await conn.fetch("SELECT state,amount_usd FROM earnings")]; costs = [dict(row) for row in await conn.fetch("SELECT service,cost_category,estimated_cost_usd,actual_cost_usd,unit,reconciled_at,external_usage_id FROM cost_ledger")]; return polli_envelope("finance_summary", summarize_finance(earnings, costs).to_dict())
    async def costs(_args):
        rows = [dict(row) for row in await conn.fetch("SELECT provider,service,cost_category,estimated_cost_usd,actual_cost_usd,unit,reconciled_at,external_usage_id FROM cost_ledger")]; raw = cost_summary_from_rows(rows); raw["groups"] = [{"key": item["group"], "amount_usd": item["estimated_usd"], "truth_label": "FACT" if item["actual_usd"] is not None else "ESTIMATE"} for item in raw.pop("groups")]; raw.pop("as_of", None); raw.pop("month", None); return polli_envelope("cost_summary", raw)
    async def target(_args):
        data = summarize_finance([dict(row) for row in await conn.fetch("SELECT state,amount_usd FROM earnings")], []).to_dict(); progress = Decimal(data["target_progress_usd"]); ppm = int((progress / Decimal("4000.000000")) * 1000000); return polli_envelope("target_progress", {"confirmed_progress_usd":data["target_progress_usd"],"accrued_unverified_usd":data["accrued_unverified"],"target_usd":data["target_usd"],"percent_of_target_ppm":max(0, ppm),"definition":"Confirmed approved, withdrawable, and withdrawn earnings only."})
    async def campaign_performance(_args): return polli_envelope("campaign_performance", {"items": []})
    async def fact_evidence(_args): return {"ok":False,"tool_name":"fact_evidence","tool_version":1,"as_of":_now().isoformat(),"truth_label":"UNKNOWN","data":None,"sources":[],"warnings":[],"cost_usd":"0.000000","page":None,"error":{"code":"NOT_FOUND","message":"No fact evidence locator was supplied.","retryable":False}}
    async def account_performance(_args): return polli_envelope("account_performance", {"items": []})
    return {"finance_summary":finance,"cost_summary":costs,"target_progress":target,"campaign_performance":campaign_performance,"fact_evidence":fact_evidence,"account_performance":account_performance}
