from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import StrEnum
from typing import Any
from hashlib import sha256
import json
from uuid import uuid4

from .c02_rules import CANONICAL_RULE_KEYS


class RightsEligibility(StrEnum):
    ELIGIBLE = "ELIGIBLE"
    INELIGIBLE = "INELIGIBLE"
    UNKNOWN = "UNKNOWN"


class AuthorizationDecision(StrEnum):
    ALLOWED = "ALLOWED"
    BLOCKED = "BLOCKED"
    UNKNOWN = "UNKNOWN"


@dataclass(frozen=True)
class RightsVersion:
    id: str
    source_id: str
    rights_version: int
    supersedes_rights_id: str | None
    eligibility: RightsEligibility
    authorized_uses: dict[str, Any]
    platform_limits: dict[str, Any]
    evidence_captured_at: datetime
    expires_at: datetime | None
    campaign_ids: tuple[str, ...] = ()


def validate_contiguous_rights_version(
    new_version: RightsVersion, previous_version: RightsVersion | None
) -> None:
    if new_version.rights_version == 1:
        if new_version.supersedes_rights_id is not None or previous_version is not None:
            raise ValueError("first rights version must not supersede another version")
        return
    if previous_version is None:
        raise ValueError("rights version cannot skip previous version")
    if new_version.source_id != previous_version.source_id:
        raise ValueError("cross-source rights version rejected")
    if new_version.rights_version != previous_version.rights_version + 1:
        raise ValueError("rights version cannot skip")
    if new_version.supersedes_rights_id != previous_version.id:
        raise ValueError("rights version must supersede latest previous rights id")


def latest_current_rights(
    versions: list[RightsVersion],
    *,
    source_id: str,
    campaign_id: str | None,
    at: datetime | None = None,
) -> RightsVersion | None:
    at = at or datetime.now(timezone.utc)
    candidates = [
        version
        for version in versions
        if version.source_id == source_id
        and (campaign_id is None or campaign_id in version.campaign_ids)
        and version.evidence_captured_at <= at
    ]
    if not candidates:
        return None
    # The newest committed version is authoritative even when it is expired
    # or restrictive.  Never fall back to an older, broader version.
    return max(candidates, key=lambda item: item.rights_version)


def stage_allowed(
    rights: RightsVersion | None,
    *,
    stage: str,
    platform: str | None = None,
    compensated: bool = False,
    duration_seconds: int | None = None,
    at: datetime | None = None,
) -> AuthorizationDecision:
    at = at or datetime.now(timezone.utc)
    if rights is None or rights.eligibility == RightsEligibility.UNKNOWN:
        return AuthorizationDecision.UNKNOWN
    if rights.eligibility == RightsEligibility.INELIGIBLE:
        return AuthorizationDecision.BLOCKED
    if rights.expires_at is not None and rights.expires_at <= at:
        return AuthorizationDecision.BLOCKED
    uses = rights.authorized_uses
    stage_key = f"may_{stage}"
    if uses.get(stage_key) is not True:
        return AuthorizationDecision.BLOCKED
    if compensated and uses.get("commercial_use") is not True:
        return AuthorizationDecision.BLOCKED
    if stage in {"edit", "render", "publish"} and uses.get("derivative_edits") is False:
        return AuthorizationDecision.BLOCKED
    if platform is not None:
        allowed_platforms = uses.get("allowed_platforms")
        if isinstance(allowed_platforms, list) and platform not in allowed_platforms:
            return AuthorizationDecision.BLOCKED
        platform_limit = rights.platform_limits.get(platform, {})
        if platform_limit.get("allowed") is False:
            return AuthorizationDecision.BLOCKED
        max_duration = platform_limit.get("max_clip_seconds")
        if duration_seconds is not None and max_duration is not None and duration_seconds > max_duration:
            return AuthorizationDecision.BLOCKED
    return AuthorizationDecision.ALLOWED


def evaluate_account_eligibility(
    campaign_rules: dict[str, Any], account_facts: dict[str, Any]
) -> AuthorizationDecision:
    material_keys = ("eligible_platforms", "eligible_regions", "eligible_account_requirements")
    if any(key in campaign_rules and campaign_rules[key] is None for key in material_keys):
        return AuthorizationDecision.UNKNOWN
    platforms = campaign_rules.get("eligible_platforms")
    if platforms is not None and account_facts.get("platform") not in platforms:
        return AuthorizationDecision.BLOCKED
    regions = campaign_rules.get("eligible_regions")
    account_region = account_facts.get("account_region")
    if regions is not None:
        if account_region is None:
            return AuthorizationDecision.UNKNOWN
        if account_region not in regions:
            return AuthorizationDecision.BLOCKED
    req = campaign_rules.get("eligible_account_requirements") or {}
    followers = account_facts.get("follower_count")
    min_followers = req.get("min_followers")
    max_followers = req.get("max_followers")
    if min_followers is not None or max_followers is not None:
        if followers is None:
            return AuthorizationDecision.UNKNOWN
        if min_followers is not None and followers < min_followers:
            return AuthorizationDecision.BLOCKED
        if max_followers is not None and followers > max_followers:
            return AuthorizationDecision.BLOCKED
    if account_facts.get("account_health") in {None, "UNKNOWN"}:
        return AuthorizationDecision.UNKNOWN
    if account_facts.get("posting_available") is not True:
        return AuthorizationDecision.UNKNOWN
    return AuthorizationDecision.ALLOWED


class SourceRightsRepository:
    """Runtime repository for the function-committed rights history."""

    def __init__(self, conn):
        self.conn = conn

    async def commit_version(
        self,
        *,
        source_id: str,
        eligibility: str,
        authorized_uses: dict[str, Any],
        platform_limits: dict[str, Any],
        evidence_type: str,
        evidence_uri: str | None,
        evidence_object_key: str | None,
        evidence_captured_at: datetime,
        expires_at: datetime | None,
        notes: str | None,
        campaign_ids: list[str],
        rights_id: str | None = None,
    ) -> str:
        if not campaign_ids or len(set(campaign_ids)) != len(campaign_ids):
            raise ValueError("rights version requires unique campaign applicability")
        if not evidence_uri and not evidence_object_key:
            raise ValueError("rights evidence is required")
        previous = await self.conn.fetchrow("SELECT id,rights_version FROM source_rights WHERE source_id=$1::uuid ORDER BY rights_version DESC LIMIT 1 FOR UPDATE", source_id)
        version = int(previous["rights_version"]) + 1 if previous else 1
        supersedes = str(previous["id"]) if previous else None
        rights_id = rights_id or str(uuid4())
        record_hash = sha256(json.dumps({"source_id":source_id,"rights_version":version,"eligibility":eligibility,"authorized_uses":authorized_uses,"platform_limits":platform_limits,"campaign_ids":sorted(campaign_ids)}, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        return str(await self.conn.fetchval("SELECT honor_commit_source_rights_version($1::uuid,$2::uuid,$3,NULLIF($4,'')::uuid,$5::source_eligibility_enum,$6::jsonb,$7::jsonb,$8,$9,$10,$11,$12,$13,$14,$15::uuid[])", rights_id, source_id, version, supersedes or "", eligibility, json.dumps(authorized_uses), json.dumps(platform_limits), evidence_type, evidence_uri, evidence_object_key, evidence_captured_at, expires_at, notes, record_hash, campaign_ids))

    async def current(self, *, source_id: str, campaign_id: str, at: datetime | None = None):
        at = at or datetime.now(timezone.utc)
        return await self.conn.fetchrow("""SELECT r.* FROM source_rights r JOIN source_rights_campaigns rc ON rc.source_rights_id=r.id WHERE r.source_id=$1::uuid AND rc.campaign_id=$2::uuid AND r.evidence_captured_at<= $3 AND r.committed_at<= $3 ORDER BY r.rights_version DESC LIMIT 1""", source_id, campaign_id, at)

    async def stage_allowed(self, *, rights_id: str, campaign_id: str, platform: str, stage: str, at: datetime | None = None) -> bool:
        at = at or datetime.now(timezone.utc)
        return bool(await self.conn.fetchval("SELECT honor_rights_stage_allowed($1::uuid,$2::uuid,$3::platform_enum,$4,$5)", rights_id, campaign_id, platform, stage, at))


async def evaluate_persisted_account_eligibility(conn, *, campaign_id: str, social_account_id: str, as_of: datetime | None = None) -> AuthorizationDecision:
    """Evaluate sealed campaign requirements against authoritative account facts."""
    as_of = as_of or datetime.now(timezone.utc)
    campaign = await conn.fetchrow("SELECT terms_snapshot_id FROM campaigns WHERE id=$1::uuid", campaign_id)
    account = await conn.fetchrow("SELECT id,platform FROM social_accounts WHERE id=$1::uuid", social_account_id)
    health = await conn.fetchrow("SELECT health,signals,account_region,follower_count,posting_available FROM account_health_snapshots WHERE social_account_id=$1::uuid AND captured_at<= $2 ORDER BY captured_at DESC LIMIT 1", social_account_id, as_of)
    if campaign is None or account is None or health is None:
        return AuthorizationDecision.UNKNOWN
    rules = await conn.fetch("SELECT rule_key,knowledge_state,typed_value FROM campaign_rule_items WHERE campaign_id=$1::uuid AND terms_snapshot_id=$2::uuid", campaign_id, campaign["terms_snapshot_id"])
    if len(rules) != len(CANONICAL_RULE_KEYS):
        return AuthorizationDecision.UNKNOWN
    facts: dict[str, Any] = {}
    for row in rules:
        if str(row["knowledge_state"]) == "UNKNOWN":
            facts[row["rule_key"]] = None
        elif row["typed_value"]:
            facts[row["rule_key"]] = row["typed_value"].get("value")
    return evaluate_account_eligibility(facts, {"platform": str(account["platform"]), "account_region": health["account_region"], "follower_count": health["follower_count"], "account_health": str(health["health"]), "posting_available": health["posting_available"]})
