import asyncio
from datetime import datetime, timezone
from decimal import Decimal

import pytest

from honor_api.costs import CostLedgerIdempotencyConflict, CostLedgerRepository, classify_ledger_row


class FakeConn:
    def __init__(self):
        self.rows = {}
        self.executes = []

    async def fetchrow(self, sql, *args):
        now = datetime.now(timezone.utc)
        if "INSERT INTO cost_ledger" in sql:
            idem = args[-1]
            if idem in self.rows:
                return None
            if "PREPAID_FUNDING" in sql:
                row = {
                    "id": args[0], "provider": args[1], "service": "PREPAID_FUNDING",
                    "cost_category": "AI_REASONING", "job_id": None, "polli_session_id": None,
                    "quantity": args[2], "unit": "USD_CASH_PURCHASE", "estimated_cost_usd": args[2],
                    "actual_cost_usd": args[2], "cost_confidence": "HIGH", "incurred_at": now,
                    "reconciled_at": now, "external_usage_id": None, "idempotency_key": idem,
                }
            else:
                row = {
                    "id": args[0], "provider": args[1], "service": args[2], "cost_category": args[3],
                    "job_id": args[4], "polli_session_id": args[5], "quantity": args[6], "unit": args[7],
                    "estimated_cost_usd": args[8], "actual_cost_usd": None, "cost_confidence": args[9],
                    "incurred_at": now, "reconciled_at": None, "external_usage_id": None,
                    "idempotency_key": idem,
                }
            self.rows[idem] = row
            return row
        if "SELECT * FROM cost_ledger WHERE idempotency_key" in sql:
            return self.rows.get(args[0])
        if "INSERT INTO provider_usage" in sql:
            return {"id": args[0]}
        if "UPDATE cost_ledger" in sql:
            for row in self.rows.values():
                if str(row["id"]) == str(args[0]) and row["actual_cost_usd"] is None:
                    row["actual_cost_usd"] = args[1]
                    row["reconciled_at"] = now
                    return row
            return None
        return None

    async def execute(self, sql, *args):
        self.executes.append((sql, args))
        return "INSERT 0 1"


def test_ledger_view_derives_frozen_status_without_schema_drift():
    now = datetime.now(timezone.utc)
    view = classify_ledger_row({
        "id": "1", "provider": "openai", "service": "responses", "job_id": None,
        "polli_session_id": None, "estimated_cost_usd": "0.25", "actual_cost_usd": None,
        "incurred_at": now, "reconciled_at": None, "external_usage_id": None,
        "idempotency_key": "op:1",
    })
    assert view.status == "RESERVED_OR_COMMITTED"
    assert view.reconciliation_state == "PENDING"
    assert view.source_of_cost_data == "HONOR_PRE_DISPATCH_ESTIMATE"


def test_reservation_exact_replay_is_read_only_and_conflict_rejects():
    conn = FakeConn(); repo = CostLedgerRepository(conn)
    first = asyncio.run(repo.reserve(
        provider="openai", service="responses", cost_category="AI_REASONING",
        estimated_usd=Decimal("1.25"), idempotency_key="reservation:1",
    ))
    replay = asyncio.run(repo.reserve(
        provider="openai", service="responses", cost_category="AI_REASONING",
        estimated_usd=Decimal("1.25"), idempotency_key="reservation:1",
    ))
    assert replay.id == first.id
    with pytest.raises(CostLedgerIdempotencyConflict):
        asyncio.run(repo.reserve(
            provider="openai", service="responses", cost_category="AI_REASONING",
            estimated_usd=Decimal("1.50"), idempotency_key="reservation:1",
        ))


def test_prepaid_exact_replay_and_commitment_use_insert_or_select():
    conn = FakeConn(); repo = CostLedgerRepository(conn)
    first = asyncio.run(repo.record_prepaid_funding(provider="openai", amount_usd=Decimal("15"), idempotency_key="fund:1"))
    replay = asyncio.run(repo.record_prepaid_funding(provider="openai", amount_usd=Decimal("15"), idempotency_key="fund:1"))
    assert replay.id == first.id
    asyncio.run(repo.record_unpaid_commitment(
        provider="digitalocean", service="droplet", cost_category="INFRASTRUCTURE",
        committed_usd=Decimal("24"), idempotency_key="commitment:1",
    ))
    assert all("DO UPDATE" not in sql for sql, _ in conn.executes)
