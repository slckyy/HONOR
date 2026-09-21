from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import StrEnum
from typing import Any


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
        and (version.expires_at is None or version.expires_at > at)
    ]
    if not candidates:
        return None
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
        max_duration = platform_limit.get("max_duration_seconds")
        if duration_seconds is not None and max_duration is not None and duration_seconds > max_duration:
            return AuthorizationDecision.BLOCKED
    return AuthorizationDecision.ALLOWED


def evaluate_account_eligibility(
    campaign_rules: dict[str, Any], account_facts: dict[str, Any]
) -> AuthorizationDecision:
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
