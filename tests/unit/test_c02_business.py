from datetime import datetime, timedelta, timezone

import pytest

from honor_api.c02_finance import (
    SelfFundedState,
    cost_summary_from_rows,
    summarize_finance,
    validate_earning_creation,
    validate_earning_transition,
)
from honor_api.c02_rights import (
    AuthorizationDecision,
    RightsEligibility,
    RightsVersion,
    latest_current_rights,
    stage_allowed,
    validate_contiguous_rights_version,
)
from honor_api.c02_rules import (
    CANONICAL_RULE_KEYS,
    KnowledgeState,
    NormalizedRule,
    seal_rule_set_hash,
    validate_owner_url,
    validate_rule,
)


def test_campaign_rule_registry_exact_32_keys():
    assert len(CANONICAL_RULE_KEYS) == 32
    assert len(set(CANONICAL_RULE_KEYS)) == 32
    assert CANONICAL_RULE_KEYS[0] == "provider"
    assert CANONICAL_RULE_KEYS[-1] == "last_verified_at"


def test_unknown_rule_must_not_have_typed_value():
    rule = NormalizedRule(
        rule_key="provider",
        knowledge_state=KnowledgeState.UNKNOWN,
        typed_value={"value_type": "STRING", "value": "x"},
        confidence=None,
        evidence_snapshot_id=None,
        evidence_locator=None,
        verified_at=None,
        verified_by="OWNER",
    )
    with pytest.raises(ValueError, match="UNKNOWN"):
        validate_rule(rule)


def test_complete_rule_set_hash_requires_32_rules():
    now = datetime.now(timezone.utc)
    rules = [
        NormalizedRule(
            rule_key=key,
            knowledge_state=KnowledgeState.UNKNOWN,
            typed_value=None,
            confidence=None,
            evidence_snapshot_id=None,
            evidence_locator=None,
            verified_at=None,
            verified_by="OWNER",
        )
        for key in CANONICAL_RULE_KEYS
    ]
    rules[0] = NormalizedRule(
        rule_key="provider",
        knowledge_state=KnowledgeState.KNOWN,
        typed_value={"value_type": "STRING", "value": "fixture"},
        confidence=None,
        evidence_snapshot_id="00000000-0000-0000-0000-000000000001",
        evidence_locator="fixture",
        verified_at=now,
        verified_by="OWNER",
    )
    digest = seal_rule_set_hash(rules)
    assert len(digest) == 64
    with pytest.raises(ValueError, match="exactly 32"):
        seal_rule_set_hash(rules[:-1])


@pytest.mark.parametrize(
    "url",
    [
        "http://127.0.0.1/campaign",
        "http://localhost/campaign",
        "http://169.254.169.254/latest/meta-data",
        "ftp://example.com/campaign",
        "https://user:pass@example.com/campaign",
        "http://10.0.0.1/campaign",
        "http://[::1]/campaign",
    ],
)
def test_owner_url_ssrf_rejections(url):
    with pytest.raises(ValueError):
        validate_owner_url(url)


def test_earning_creation_and_transition_graph():
    validate_earning_creation(None)
    validate_earning_creation("ACCRUED_UNVERIFIED")
    with pytest.raises(ValueError):
        validate_earning_creation("APPROVED")
    validate_earning_transition("ACCRUED_UNVERIFIED", "APPROVED")
    validate_earning_transition("APPROVED", "WITHDRAWABLE")
    validate_earning_transition("WITHDRAWABLE", "WITHDRAWN")
    with pytest.raises(ValueError):
        validate_earning_transition("ACCRUED_UNVERIFIED", "WITHDRAWN")
    with pytest.raises(ValueError):
        validate_earning_transition("WITHDRAWN", "VOIDED")


def test_finance_summary_no_double_count_and_unknown_cost_completeness():
    summary = summarize_finance(
        [
            {"state": "ACCRUED_UNVERIFIED", "amount_usd": "99.000000"},
            {"state": "APPROVED", "amount_usd": "100.000000"},
            {"state": "WITHDRAWABLE", "amount_usd": "25.000000"},
            {"state": "WITHDRAWN", "amount_usd": "5.000000"},
            {"state": "VOIDED", "amount_usd": "1000.000000"},
        ],
        [{"service": "GPU", "estimated_cost_usd": "10.000000", "actual_cost_usd": None}],
    )
    assert summary.confirmed_gross_revenue == 130
    assert summary.net_profit_booked is None
    assert summary.self_funded_state == SelfFundedState.UNKNOWN_NOT_VERIFIED


def test_self_funded_true_only_confirmed_revenue_exceeds_complete_costs():
    summary = summarize_finance(
        [{"state": "APPROVED", "amount_usd": "20.000000"}],
        [{"service": "GPU", "estimated_cost_usd": "10.000000", "actual_cost_usd": "10.000000"}],
    )
    assert summary.self_funded_state == SelfFundedState.FACTORY_SELF_FUNDED
    assert summary.to_dict()["target_progress_usd"] == "20.000000"


def test_cost_summary_uses_c01_governor_thresholds():
    result = cost_summary_from_rows(
        [
            {"provider": "OPENAI", "service": "PREPAID_FUNDING", "estimated_cost_usd": "20.000000", "actual_cost_usd": "20.000000"},
            {"provider": "OPENAI", "service": "OPENAI", "unit": "OPERATION", "estimated_cost_usd": "42.990000", "actual_cost_usd": "42.990000"},
            {"service": "GPU", "unit": "COMMITTED_OPERATION", "estimated_cost_usd": "0.020000", "actual_cost_usd": None},
        ]
    )
    assert result["governor_state"] == "OPTIONAL_PAUSED"
    assert result["optional_pause_usd"] == "43.000000"
    assert result["reserve_mode_usd"] == "51.030000"
    assert result["hard_cap_usd"] == "56.030000"


def test_rights_versions_are_contiguous_and_latest_restrictive_wins():
    now = datetime.now(timezone.utc)
    v1 = RightsVersion(
        id="r1",
        source_id="s1",
        rights_version=1,
        supersedes_rights_id=None,
        eligibility=RightsEligibility.ELIGIBLE,
        authorized_uses={
            "may_ingest": True,
            "may_edit": True,
            "may_render": True,
            "may_publish": True,
            "commercial_use": True,
            "derivative_edits": True,
            "allowed_platforms": ["TIKTOK"],
        },
        platform_limits={"TIKTOK": {"max_duration_seconds": 60}},
        evidence_captured_at=now - timedelta(days=2),
        expires_at=None,
        campaign_ids=("c1",),
    )
    v2 = RightsVersion(
        id="r2",
        source_id="s1",
        rights_version=2,
        supersedes_rights_id="r1",
        eligibility=RightsEligibility.INELIGIBLE,
        authorized_uses={},
        platform_limits={},
        evidence_captured_at=now - timedelta(days=1),
        expires_at=None,
        campaign_ids=("c1",),
    )
    validate_contiguous_rights_version(v1, None)
    validate_contiguous_rights_version(v2, v1)
    current = latest_current_rights([v1, v2], source_id="s1", campaign_id="c1", at=now)
    assert current == v2
    assert stage_allowed(current, stage="publish", platform="TIKTOK", compensated=True) == AuthorizationDecision.BLOCKED
    old = latest_current_rights([v1, v2], source_id="s1", campaign_id="c1", at=now - timedelta(days=1, hours=12))
    assert stage_allowed(old, stage="publish", platform="TIKTOK", compensated=True, duration_seconds=30) == AuthorizationDecision.ALLOWED
