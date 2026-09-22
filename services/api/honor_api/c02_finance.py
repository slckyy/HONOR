from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from decimal import Decimal
from enum import StrEnum
from typing import Any

from .costs import D, HARD, RESERVE, OPTIONAL, state as governor_state

TARGET_USD = D("4000.000000")


class EarningState(StrEnum):
    ACCRUED_UNVERIFIED = "ACCRUED_UNVERIFIED"
    APPROVED = "APPROVED"
    WITHDRAWABLE = "WITHDRAWABLE"
    WITHDRAWN = "WITHDRAWN"
    VOIDED = "VOIDED"


class SelfFundedState(StrEnum):
    FACTORY_SELF_FUNDED = "FACTORY_SELF_FUNDED"
    NOT_SELF_FUNDED = "NOT_SELF_FUNDED"
    UNKNOWN_NOT_VERIFIED = "UNKNOWN_NOT_VERIFIED"


ALLOWED_EARNING_TRANSITIONS = {
    EarningState.ACCRUED_UNVERIFIED: {EarningState.APPROVED, EarningState.VOIDED},
    EarningState.APPROVED: {EarningState.WITHDRAWABLE, EarningState.VOIDED},
    EarningState.WITHDRAWABLE: {EarningState.WITHDRAWN, EarningState.VOIDED},
    EarningState.WITHDRAWN: set(),
    EarningState.VOIDED: set(),
}


def usd(value: Decimal | str | int) -> str:
    return f"{D(value):.6f}"


def validate_earning_creation(state: str | None) -> None:
    if state not in {None, EarningState.ACCRUED_UNVERIFIED.value}:
        raise ValueError("earning creation must be ACCRUED_UNVERIFIED")


def validate_earning_transition(from_state: str, to_state: str) -> None:
    src = EarningState(from_state)
    dst = EarningState(to_state)
    if dst not in ALLOWED_EARNING_TRANSITIONS[src]:
        raise ValueError("invalid earning state transition")


@dataclass(frozen=True)
class FinanceSummary:
    accrued_unverified: Decimal
    approved: Decimal
    withdrawable: Decimal
    withdrawn: Decimal
    booked_spend: Decimal
    actual_reconciled_spend: Decimal
    unreconciled_cost_count: int
    costs_complete: bool
    as_of: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    infrastructure_spend: Decimal = Decimal("0")
    polli_spend: Decimal = Decimal("0")

    @property
    def confirmed_gross_revenue(self) -> Decimal:
        return D(self.approved + self.withdrawable + self.withdrawn)

    @property
    def net_profit_booked(self) -> Decimal | None:
        if not self.costs_complete:
            return None
        return D(self.confirmed_gross_revenue - self.booked_spend)

    @property
    def self_funded_state(self) -> SelfFundedState:
        if not self.costs_complete:
            return SelfFundedState.UNKNOWN_NOT_VERIFIED
        if self.confirmed_gross_revenue > self.booked_spend:
            return SelfFundedState.FACTORY_SELF_FUNDED
        return SelfFundedState.NOT_SELF_FUNDED

    def to_dict(self) -> dict[str, Any]:
        net = self.net_profit_booked
        return {
            "accrued_unverified": usd(self.accrued_unverified),
            "approved": usd(self.approved),
            "withdrawable": usd(self.withdrawable),
            "withdrawn": usd(self.withdrawn),
            "confirmed_gross_revenue": usd(self.confirmed_gross_revenue),
            "booked_spend": usd(self.booked_spend),
            "actual_reconciled_spend": usd(self.actual_reconciled_spend),
            "net_profit_booked": usd(net) if net is not None else None,
            "net_profit_truth_state": "FACT" if net is not None else "INCOMPLETE_UNKNOWN",
            "target_progress_usd": usd(self.confirmed_gross_revenue),
            "target_usd": usd(TARGET_USD),
            "self_funded_state": self.self_funded_state.value,
            "unreconciled_cost_count": self.unreconciled_cost_count,
            "completeness": "COMPLETE" if self.costs_complete else "INCOMPLETE_UNKNOWN",
        }

    def to_openapi_dict(self) -> dict[str, Any]:
        net = self.net_profit_booked
        return {
            "as_of": self.as_of.isoformat(),
            "currency": "USD",
            "accrued_unverified_usd": usd(self.accrued_unverified),
            "approved_usd": usd(self.approved),
            "withdrawable_usd": usd(self.withdrawable),
            "withdrawn_usd": usd(self.withdrawn),
            "gross_campaign_revenue_usd": usd(self.confirmed_gross_revenue),
            "infrastructure_api_spend_usd": usd(self.infrastructure_spend),
            "polli_voice_reasoning_spend_usd": usd(self.polli_spend),
            "lifetime_revenue_usd": usd(self.confirmed_gross_revenue),
            "lifetime_spend_usd": usd(self.booked_spend),
            "net_profit_usd": usd(net) if net is not None else None,
            "monthly_target_usd": usd(TARGET_USD),
            "monthly_target_progress_usd": usd(self.confirmed_gross_revenue),
            "net_profit_truth_state": "FACT" if net is not None else "INCOMPLETE_UNKNOWN",
            "self_funded_state": self.self_funded_state.value,
        }


def summarize_finance(
    earnings: list[dict[str, Any]],
    costs: list[dict[str, Any]],
    *,
    as_of: datetime | None = None,
    period_start: datetime | None = None,
) -> FinanceSummary:
    buckets = {state.value: D("0") for state in EarningState}
    for row in earnings:
        state = EarningState(row["state"])
        if state == EarningState.VOIDED:
            continue
        if as_of is not None and row.get("recognized_at") is not None and row["recognized_at"] > as_of:
            continue
        if period_start is not None and row.get("recognized_at") is not None and row["recognized_at"] < period_start:
            continue
        buckets[state.value] = D(buckets[state.value] + D(row["amount_usd"]))
    booked = D("0")
    actual = D("0")
    unreconciled = 0
    infrastructure = D("0")
    polli = D("0")
    for row in costs:
        service = row.get("service")
        estimate = D(row.get("estimated_cost_usd", "0"))
        actual_cost = row.get("actual_cost_usd")
        if service == "PREPAID_FUNDING":
            # A prepaid purchase is cash/governor exposure, not an additional
            # economic operating expense.  Usage rows are booked once below.
            continue
        amount = D(actual_cost if actual_cost is not None else estimate)
        booked = D(booked + amount)
        category = str(row.get("cost_category", ""))
        if category == "INFRASTRUCTURE" or service in {"R2", "REDIS", "POSTGRES", "INFRASTRUCTURE"}:
            infrastructure = D(infrastructure + amount)
        if category in {"POLLI_VOICE", "AI_REASONING"} or service in {"POLLI_VOICE", "AI_REASONING", "POLLI"}:
            polli = D(polli + amount)
        if actual_cost is None:
            unreconciled += 1
        else:
            actual = D(actual + D(actual_cost))
    return FinanceSummary(
        accrued_unverified=buckets[EarningState.ACCRUED_UNVERIFIED.value],
        approved=buckets[EarningState.APPROVED.value],
        withdrawable=buckets[EarningState.WITHDRAWABLE.value],
        withdrawn=buckets[EarningState.WITHDRAWN.value],
        booked_spend=booked,
        actual_reconciled_spend=actual,
        unreconciled_cost_count=unreconciled,
        costs_complete=unreconciled == 0,
        as_of=as_of or datetime.now(timezone.utc),
        infrastructure_spend=infrastructure,
        polli_spend=polli,
    )


def cost_summary_from_rows(rows: list[dict[str, Any]], *, month: str | None = None) -> dict[str, Any]:
    prepaid = D("0")
    prepaid_by_provider: dict[str, Decimal] = {}
    cash_spend = D("0")
    actual_spend = D("0")
    estimated_unreconciled = D("0")
    committed = D("0")
    queued = D("0")
    groups: dict[str, dict[str, Decimal | None]] = {}
    for row in rows:
        service = str(row.get("service"))
        provider = str(row.get("provider") or service)
        estimate = D(row.get("estimated_cost_usd", "0"))
        actual = row.get("actual_cost_usd")
        if service == "PREPAID_FUNDING":
            amount = D(actual if actual is not None else estimate)
            prepaid = D(prepaid + amount)
            prepaid_by_provider[provider] = D(prepaid_by_provider.get(provider, D("0")) + amount)
            cash_spend = D(cash_spend + amount)
            group = groups.setdefault(service, {"estimated": D("0"), "actual": None})
            group["estimated"] = D(group["estimated"] + estimate)
            if actual is not None:
                group["actual"] = D((group["actual"] or D("0")) + D(actual))
            continue
        amount = D(actual if actual is not None else estimate)
        if actual is None:
            estimated_unreconciled = D(estimated_unreconciled + amount)
            if str(row.get("unit")) == "COMMITTED_OPERATION":
                committed = D(committed + amount)
            else:
                queued = D(queued + amount)
        else:
            actual_spend = D(actual_spend + amount)
            # A prepaid balance can shield only usage from the same provider.
            provider_credit = prepaid_by_provider.get(provider, D("0"))
            consumed = D(min(provider_credit, amount))
            prepaid_by_provider[provider] = D(provider_credit - consumed)
            cash_spend = D(cash_spend + amount - consumed)
        group = groups.setdefault(service, {"estimated": D("0"), "actual": None})
        group["estimated"] = D(group["estimated"] + estimate)
        if actual is not None:
            group["actual"] = D((group["actual"] or D("0")) + D(actual))
    remaining_credit = D(sum(prepaid_by_provider.values(), Decimal("0")))
    # Only queued work above the remaining prepaid credit is unfunded.  Cash
    # purchases are already counted in full and are never counted again when
    # their credit is consumed.
    # Usage consumes prepaid credit first.  Once the credit is exhausted,
    # usage above the remaining balance is real governor exposure; queued work
    # is treated the same way when it is admitted without sufficient credit.
    usage_unfunded = D("0")
    admitted_unfunded = D(max(usage_unfunded, queued - remaining_credit))
    exposure = D(cash_spend + committed + admitted_unfunded)
    now = datetime.now(timezone.utc)
    return {
        "as_of": now.isoformat(),
        "month": month or now.strftime("%Y-%m"),
        "cash_spend_counted_usd": usd(cash_spend),
        "unpaid_committed_usd": usd(committed),
        "admitted_queued_unfunded_usd": usd(admitted_unfunded),
        "prepaid_funding_purchased_usd": usd(prepaid),
        "prepaid_credit_remaining_usd": usd(remaining_credit),
        "governor_exposure_usd": usd(exposure),
        "projected_month_end_usd": usd(exposure),
        "remaining_hard_cap_usd": usd(D(HARD - exposure)),
        "optional_pause_usd": usd(OPTIONAL),
        "reserve_mode_usd": usd(RESERVE),
        "hard_cap_usd": usd(HARD),
        "governor_state": governor_state(exposure).value,
        "groups": [
            {"group": key, "estimated_usd": usd(value["estimated"]), "actual_usd": usd(value["actual"]) if value["actual"] is not None else None, "confidence": "HIGH" if value["actual"] is not None else "LOW"}
            for key, value in sorted(groups.items())
        ],
    }


def polli_envelope(tool_name: str, data: dict[str, Any], truth_label: str = "FACT") -> dict[str, Any]:
    return {
        "ok": True,
        "tool_name": tool_name,
        "tool_version": 1,
        "as_of": datetime.now(timezone.utc).isoformat(),
        "truth_label": truth_label,
        "data": data,
        "sources": [
            {
                "ref": f"{tool_name}:derived-query",
                "kind": "DERIVED_QUERY",
                "as_of": datetime.now(timezone.utc).isoformat(),
                "description": "Deterministic C02 service calculation from authoritative rows.",
            }
        ],
        "warnings": [],
        "cost_usd": "0.000000",
        "page": None,
    }
