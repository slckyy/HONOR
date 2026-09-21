from __future__ import annotations

import asyncio
from decimal import Decimal
from uuid import uuid4

import pytest

from honor_api.costs import CostLedgerIdempotencyConflict, CostLedgerRepository
from tests.integration.conftest import APP_URL, OWNER, admin_psql

pytestmark = pytest.mark.integration


async def _run() -> None:
    import asyncpg

    conn = await asyncpg.connect(APP_URL)
    idem = f"c01-cost-{uuid4()}"
    funding_idem = f"c01-funding-{uuid4()}"
    try:
        async with conn.transaction():
            await conn.execute("SELECT set_config('honor.owner_user_id',$1,true)", OWNER)
            await conn.execute("SELECT set_config('honor.request_id',$1,true)", str(uuid4()))
            repo = CostLedgerRepository(conn)
            first = await repo.reserve(
                provider="openai",
                service="responses",
                cost_category="AI_REASONING",
                estimated_usd=Decimal("1.250000"),
                idempotency_key=idem,
            )
            replay = await repo.reserve(
                provider="openai",
                service="responses",
                cost_category="AI_REASONING",
                estimated_usd=Decimal("1.250000"),
                idempotency_key=idem,
            )
            assert replay.id == first.id
            with pytest.raises(CostLedgerIdempotencyConflict):
                await repo.reserve(
                    provider="openai",
                    service="responses",
                    cost_category="AI_REASONING",
                    estimated_usd=Decimal("2.000000"),
                    idempotency_key=idem,
                )
            funding = await repo.record_prepaid_funding(
                provider="openai",
                amount_usd=Decimal("15.000000"),
                idempotency_key=funding_idem,
            )
            funding_replay = await repo.record_prepaid_funding(
                provider="openai",
                amount_usd=Decimal("15.000000"),
                idempotency_key=funding_idem,
            )
            assert funding_replay.id == funding.id
            with pytest.raises(CostLedgerIdempotencyConflict):
                await repo.record_prepaid_funding(
                    provider="openai",
                    amount_usd=Decimal("16.000000"),
                    idempotency_key=funding_idem,
                )

        async with conn.transaction():
            await conn.execute("SELECT set_config('honor.owner_user_id',$1,true)", OWNER)
            # Isolate the expected privilege error in a savepoint so the outer
            # transaction can exit cleanly instead of remaining aborted.
            with pytest.raises(asyncpg.InsufficientPrivilegeError):
                async with conn.transaction():
                    await conn.execute("UPDATE cost_ledger SET provider='mutated' WHERE id=$1::uuid", first.id)

        async with conn.transaction():
            await conn.execute("SELECT set_config('honor.owner_user_id',$1,true)", OWNER)
            request_id = str(uuid4())
            await conn.execute("SELECT set_config('honor.request_id',$1,true)", request_id)
            repo = CostLedgerRepository(conn)
            reconciled = await repo.reconcile(first.id, Decimal("1.100000"))
            assert reconciled.actual_cost_usd == Decimal("1.100000")
            with pytest.raises(ValueError):
                await repo.reconcile(first.id, Decimal("1.100000"))
    finally:
        await conn.close()

    assert admin_psql(
        f"SELECT count(*) FROM audit_log WHERE target_type='cost_ledger' AND target_id='{first.id}'::uuid AND action='COST_LEDGER_RECONCILED'"
    ) == "1"


def test_cost_ledger_idempotency_and_one_time_reconciliation(migrated_database):
    if not APP_URL:
        pytest.skip("TEST_DATABASE_APP_URL not configured")
    asyncio.run(_run())
