from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from enum import StrEnum
from hashlib import sha256
import ipaddress
import json
from pathlib import Path
import socket
from typing import Any
from urllib.parse import urlparse

from jsonschema import Draft202012Validator, FormatChecker


_ROOT = Path(__file__).resolve().parents[3]
_REGISTRY = json.loads((_ROOT / "docs/architecture/c00-approved/HONOR_CAMPAIGN_RULE_REGISTRY.json").read_text())
_RULE_KEYS = _REGISTRY["keys"]
CANONICAL_RULE_KEYS = tuple(_RULE_KEYS.keys())

# Kept as a compatibility view for callers; the frozen registry remains the
# only source of truth for key/value types and per-key schemas.
RULE_VALUE_TYPES = {key: value["value_type"] for key, value in _RULE_KEYS.items()}

_SCHEMA_VALIDATORS = {
    key: Draft202012Validator(value["typed_value_schema"], format_checker=FormatChecker())
    for key, value in _RULE_KEYS.items()
}

_LEGACY_CANONICAL_RULE_KEYS = (
    "provider",
    "campaign_url",
    "external_campaign_id",
    "status",
    "compensation_model",
    "cpm_or_rate",
    "minimum_views",
    "max_payout_per_clip",
    "total_budget",
    "remaining_budget",
    "start_at",
    "end_at",
    "deadline_at",
    "eligible_platforms",
    "eligible_regions",
    "eligible_account_requirements",
    "required_tags",
    "required_mentions",
    "required_hashtags",
    "disclosure_requirements",
    "source_material_restrictions",
    "clip_length_min_seconds",
    "clip_length_max_seconds",
    "content_restrictions",
    "editing_restrictions",
    "uniqueness_rules",
    "submission_format",
    "analytics_window",
    "payout_window",
    "render_audio_rules",
    "platform_native_audio_rules",
    "last_verified_at",
)

_LEGACY_RULE_VALUE_TYPES = {
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

ALLOWED_RESTRICTION_PLACEMENT = {
    "source_material_restrictions": {
        ("CAMPAIGN_AUTHORIZED_SOURCE_ONLY", "REQUIRE", "SOURCE"),
        ("OWNER_OWNED_SOURCE_ONLY", "REQUIRE", "SOURCE"),
        ("NO_THIRD_PARTY_SOURCE", "PROHIBIT", "SOURCE"),
    },
    "content_restrictions": {
        ("NO_PROFANITY", "PROHIBIT", "CONTENT"),
        ("BRAND_SAFE_ONLY", "REQUIRE", "CONTENT"),
        ("NO_MISLEADING_CLAIMS", "PROHIBIT", "CONTENT"),
    },
    "editing_restrictions": {
        ("NO_CROP", "PROHIBIT", "EDIT"),
        ("NO_SPEED_CHANGE", "PROHIBIT", "EDIT"),
        ("NO_TEXT_OVERLAY", "PROHIBIT", "EDIT"),
    },
    "uniqueness_rules": {
        ("NO_REUSED_EDIT", "PROHIBIT", "UNIQUENESS"),
        ("UNIQUE_PER_ACCOUNT", "REQUIRE", "UNIQUENESS"),
        ("UNIQUE_PER_CAMPAIGN", "REQUIRE", "UNIQUENESS"),
    },
}


class KnowledgeState(StrEnum):
    KNOWN = "KNOWN"
    UNKNOWN = "UNKNOWN"
    NOT_APPLICABLE = "NOT_APPLICABLE"


@dataclass(frozen=True)
class NormalizedRule:
    rule_key: str
    knowledge_state: KnowledgeState
    typed_value: dict[str, Any] | None
    confidence: Decimal | None
    evidence_snapshot_id: str | None
    evidence_locator: str | None
    verified_at: datetime | None
    verified_by: str


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), default=str)


def _decimal(value: Any) -> Decimal:
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError) as exc:
        raise ValueError("invalid decimal value") from exc


def _parse_time(value: Any) -> datetime:
    if not isinstance(value, str):
        raise ValueError("timestamp rule value must be a string")
    return datetime.fromisoformat(value.replace("Z", "+00:00"))


def validate_typed_value(rule_key: str, typed_value: dict[str, Any]) -> None:
    if rule_key not in _SCHEMA_VALIDATORS:
        raise ValueError("non-canonical campaign rule key")
    errors = sorted(_SCHEMA_VALIDATORS[rule_key].iter_errors(typed_value), key=lambda e: list(e.path))
    if errors:
        raise ValueError(f"invalid frozen schema for {rule_key}: {errors[0].message}")


def validate_rule(rule: NormalizedRule) -> None:
    if rule.rule_key not in CANONICAL_RULE_KEYS:
        raise ValueError("non-canonical campaign rule key")
    # OWNER_MANUAL was used by pre-C02 helper callers; persisted DB writes use
    # the frozen OWNER enum value exclusively.
    if rule.verified_by not in {"API", "IMPORTER", "OWNER", "BUILDER", "OWNER_MANUAL"}:
        raise ValueError("verified_by must use the frozen enum")
    if rule.knowledge_state == KnowledgeState.UNKNOWN:
        if rule.typed_value is not None:
            raise ValueError("UNKNOWN rule must have null typed value")
        return
    if rule.evidence_snapshot_id is None or rule.verified_at is None:
        raise ValueError("KNOWN/NOT_APPLICABLE rule requires evidence and verification")
    if rule.verified_at > datetime.now(timezone.utc):
        raise ValueError("campaign rule may not claim verification from the future")
    if rule.knowledge_state == KnowledgeState.NOT_APPLICABLE:
        if rule.typed_value is not None:
            raise ValueError("NOT_APPLICABLE rule requires null typed value")
        return
    if rule.typed_value is None:
        raise ValueError("KNOWN rule requires typed value")
    validate_typed_value(rule.rule_key, rule.typed_value)


def validate_complete_rule_set(rules: list[NormalizedRule]) -> None:
    keys = [rule.rule_key for rule in rules]
    if sorted(keys) != sorted(CANONICAL_RULE_KEYS) or len(keys) != 32 or len(set(keys)) != 32:
        raise ValueError("rule-set seal requires exactly 32 canonical normalized rules")
    for rule in rules:
        validate_rule(rule)
    by_key = {rule.rule_key: rule for rule in rules}
    min_rule = by_key["clip_length_min_seconds"]
    max_rule = by_key["clip_length_max_seconds"]
    if min_rule.typed_value and max_rule.typed_value:
        if _decimal(min_rule.typed_value["value"]) > _decimal(max_rule.typed_value["value"]):
            raise ValueError("clip length min exceeds max")
    total = by_key["total_budget"]
    remaining = by_key["remaining_budget"]
    if total.typed_value and remaining.typed_value:
        if _decimal(remaining.typed_value["value"]) > _decimal(total.typed_value["value"]):
            raise ValueError("remaining budget exceeds total budget")
    start = by_key["start_at"].typed_value
    end = by_key["end_at"].typed_value
    if start and end and _parse_time(start["value"]) >= _parse_time(end["value"]):
        raise ValueError("campaign start_at must precede end_at")


def seal_rule_set_hash(rules: list[NormalizedRule]) -> str:
    validate_complete_rule_set(rules)
    payload = [
        {
            "rule_key": rule.rule_key,
            "knowledge_state": rule.knowledge_state.value,
            "typed_value": rule.typed_value,
            "evidence_snapshot_id": rule.evidence_snapshot_id,
            "evidence_locator": rule.evidence_locator,
            "verified_at": rule.verified_at.isoformat() if rule.verified_at else None,
            "verified_by": rule.verified_by,
        }
        for rule in sorted(rules, key=lambda item: item.rule_key)
    ]
    return sha256(canonical_json(payload).encode()).hexdigest()


def validate_owner_url(url: str, resolver=socket.getaddrinfo) -> None:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        raise ValueError("unsupported URL scheme")
    if parsed.username or parsed.password:
        raise ValueError("URL credentials are not allowed")
    if not parsed.hostname:
        raise ValueError("URL host is required")
    host = parsed.hostname.lower()
    if host in {"localhost", "localhost.localdomain"}:
        raise ValueError("localhost URLs are not allowed")
    try:
        ipaddress.ip_address(host)
        hosts = [(None, None, None, None, (host, 0))]
    except ValueError:
        hosts = resolver(host, parsed.port or (443 if parsed.scheme == "https" else 80), type=socket.SOCK_STREAM)
    for info in hosts:
        ip = ipaddress.ip_address(info[4][0])
        if (
            ip.is_loopback
            or ip.is_private
            or ip.is_link_local
            or ip.is_multicast
            or ip.is_reserved
            or ip.is_unspecified
            or str(ip) == "169.254.169.254"
        ):
            raise ValueError("URL resolves to a non-public address")
