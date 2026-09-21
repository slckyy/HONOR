from __future__ import annotations

import asyncio
import os
from datetime import datetime, timezone
from uuid import uuid4

import pytest

from honor_worker.durable_jobs import (
    claim_job_on_connection,
    execute_foundation_job,
    owner_tx,
    release_execution_lock,
    retry_delay,
    try_execution_lock,
)
from honor_worker.reconciler import reconcile_once
from tests.integration.conftest import APP_URL, OWNER, admin_psql

pytestmark = pytest.mark.integration
REDIS_URL = os.getenv("TEST_REDIS_URL")


async def _connect_app():
    import asyncpg

    return await asyncpg.connect(APP_URL)


async def _insert_job(*, max_attempts: int = 5, attempt: int = 0) -> tuple[str, str]:
    job_id, token = str(uuid4()), str(uuid4())
    conn = await _connect_app()
    try:
        async with conn.transaction():
            await conn.execute("SELECT set_config('honor.owner_user_id',$1,true)", OWNER)
            await conn.execute(
                """
                INSERT INTO jobs(id,job_type,domain_entity_type,domain_entity_id,state,stage,attempt,max_attempts,
                  idempotency_key,dispatch_token,correlation_id,timeout_seconds)
                VALUES($1::uuid,'foundation-echo','foundation',$2::uuid,'queued','backup',$3,$4,$5,$6::uuid,$7::uuid,30)
                """,
                job_id,
                str(uuid4()),
                attempt,
                max_attempts,
                f"foundation:{job_id}",
                token,
                str(uuid4()),
            )
    finally:
        await conn.close()
    return job_id, token


async def _state(job_id: str) -> str:
    conn = await _connect_app()
    try:
        async with conn.transaction():
            await conn.execute("SELECT set_config('honor.owner_user_id',$1,true)", OWNER)
            return str(await conn.fetchval("SELECT state::text FROM jobs WHERE id=$1::uuid", job_id))
    finally:
        await conn.close()


async def _lease(conn, job_id: str):
    async with owner_tx(conn):
        return await conn.fetchval(
            "SELECT lease_expires_at FROM jobs WHERE id=$1::uuid", job_id
        )


async def _set_expired(job_id: str) -> None:
    conn = await _connect_app()
    try:
        async with conn.transaction():
            await conn.execute("SELECT set_config('honor.owner_user_id',$1,true)", OWNER)
            await conn.execute(
                "UPDATE jobs SET heartbeat_at=statement_timestamp()-interval '2 minutes', lease_expires_at=statement_timestamp()-interval '1 minute' WHERE id=$1::uuid",
                job_id,
            )
    finally:
        await conn.close()


async def _age_queued(job_id: str) -> None:
    conn = await _connect_app()
    try:
        async with conn.transaction():
            await conn.execute("SELECT set_config('honor.owner_user_id',$1,true)", OWNER)
            await conn.execute(
                "UPDATE jobs SET updated_at=statement_timestamp()-interval '2 minutes' WHERE id=$1::uuid AND state='queued'",
                job_id,
            )
    finally:
        await conn.close()


async def _set_due(job_id: str) -> None:
    conn = await _connect_app()
    try:
        async with conn.transaction():
            await conn.execute("SELECT set_config('honor.owner_user_id',$1,true)", OWNER)
            await conn.execute("UPDATE jobs SET available_at=statement_timestamp()-interval '1 second' WHERE id=$1::uuid", job_id)
    finally:
        await conn.close()


def test_retry_schedule_is_frozen():
    assert [retry_delay(i) for i in range(1, 6)] == [30, 120, 600, 1800, 7200]


def test_success_duplicate_and_terminal_redispatch_rules(migrated_database):
    async def run():
        job_id, token = await _insert_job()
        first = await execute_foundation_job(job_id, token)
        assert first["state"] == "succeeded"
        assert await _state(job_id) == "succeeded"
        duplicate = await execute_foundation_job(job_id, token)
        assert duplicate["duplicate_or_ineligible"] is True
        published = []
        await reconcile_once(publisher=lambda jid, tok: published.append((jid, tok)))
        assert all(jid != job_id for jid, _ in published)
        assert admin_psql(f"SELECT count(*) FROM events WHERE job_id='{job_id}'::uuid AND event_name='JOB_SUCCEEDED'") == "1"

    asyncio.run(run())


def test_redis_flush_cannot_lose_postgres_job_and_reconciler_redispatches(migrated_database):
    if not REDIS_URL:
        if os.getenv("CI") == "true":
            pytest.fail("TEST_REDIS_URL is mandatory in CI")
        pytest.skip("TEST_REDIS_URL not configured")

    async def run():
        import redis.asyncio as redis

        job_id, token = await _insert_job()
        client = redis.from_url(REDIS_URL)
        try:
            await client.set("honor:ephemeral-dispatch-proof", "1")
            await client.flushdb()
            assert await client.get("honor:ephemeral-dispatch-proof") is None
        finally:
            await client.aclose()
        assert await _state(job_id) == "queued"
        await _age_queued(job_id)
        published = []
        stats = await reconcile_once(publisher=lambda jid, tok: published.append((jid, tok)))
        assert stats.published >= 1
        assert (job_id, token) in published

    asyncio.run(run())


def test_expired_lease_recovers_but_active_execution_lock_is_not_duplicated(migrated_database):
    async def run():
        # Dead worker case: no session execution lock remains, so expired running work is recovered.
        job_id, token = await _insert_job()
        conn = await _connect_app()
        try:
            claimed = await claim_job_on_connection(conn, job_id, token)
            assert claimed is not None
        finally:
            await conn.close()
        await _set_expired(job_id)
        published = []
        stats = await reconcile_once(publisher=lambda jid, tok: published.append((jid, tok)))
        assert stats.expired_to_retrying == 1
        assert await _state(job_id) == "retrying"
        assert all(jid != job_id for jid, _ in published)
        await _set_due(job_id)
        await reconcile_once(publisher=lambda jid, tok: published.append((jid, tok)))
        assert await _state(job_id) == "queued"
        assert (job_id, token) in published

        # Suspect lease but process lock still held: reconciler proves activity and does not duplicate.
        live_id, live_token = await _insert_job()
        live_conn = await _connect_app()
        locked = await try_execution_lock(live_conn, live_id)
        assert locked
        try:
            assert await claim_job_on_connection(live_conn, live_id, live_token) is not None
            await _set_expired(live_id)
            stats = await reconcile_once(publisher=lambda jid, tok: None)
            assert stats.active_lease_skipped >= 1
            assert await _state(live_id) == "running"
        finally:
            await release_execution_lock(live_conn, live_id)
            await live_conn.close()

    asyncio.run(run())


def test_expired_exhausted_job_becomes_terminal_and_is_not_published(migrated_database):
    async def run():
        job_id, token = await _insert_job(max_attempts=1)
        conn = await _connect_app()
        try:
            assert await claim_job_on_connection(conn, job_id, token) is not None
        finally:
            await conn.close()
        await _set_expired(job_id)
        published = []
        stats = await reconcile_once(publisher=lambda jid, tok: published.append((jid, tok)))
        assert stats.expired_to_terminal == 1
        assert await _state(job_id) == "failed-terminal"
        assert all(jid != job_id for jid, _ in published)

    asyncio.run(run())

def test_retryable_and_nonretryable_failure_transitions(migrated_database):
    from honor_worker.durable_jobs import fail_on_connection

    async def run():
        retry_id, retry_token = await _insert_job(max_attempts=5)
        conn = await _connect_app()
        try:
            assert await claim_job_on_connection(conn, retry_id, retry_token) is not None
            state = await fail_on_connection(
                conn,
                retry_id,
                retry_token,
                code="FOUNDATION_RETRYABLE",
                detail="transient test fixture",
                retryable=True,
            )
            assert state == "retrying"
        finally:
            await conn.close()
        assert await _state(retry_id) == "retrying"
        assert admin_psql(
            f"SELECT count(*) FROM events WHERE job_id='{retry_id}'::uuid "
            "AND event_name='JOB_RETRY_SCHEDULED'"
        ) == "1"

        fail_id, fail_token = await _insert_job(max_attempts=1)
        conn = await _connect_app()
        try:
            assert await claim_job_on_connection(conn, fail_id, fail_token) is not None
            state = await fail_on_connection(
                conn,
                fail_id,
                fail_token,
                code="FOUNDATION_NONRETRYABLE",
                detail="permanent test fixture",
                retryable=False,
            )
            assert state == "failed-terminal"
        finally:
            await conn.close()
        assert await _state(fail_id) == "failed-terminal"
        assert admin_psql(
            f"SELECT count(*) FROM events WHERE job_id='{fail_id}'::uuid "
            "AND event_name='JOB_FAILED_TERMINAL'"
        ) == "1"

    asyncio.run(run())


def test_heartbeat_renews_running_lease(migrated_database):
    from honor_worker.durable_jobs import heartbeat_on_connection

    async def run():
        job_id, token = await _insert_job()
        conn = await _connect_app()
        try:
            assert await claim_job_on_connection(conn, job_id, token) is not None
            before = await _lease(conn, job_id)
            await asyncio.sleep(0.01)
            assert await heartbeat_on_connection(conn, job_id, token)
            after = await _lease(conn, job_id)
            assert after > before
        finally:
            await conn.close()

    asyncio.run(run())


def test_real_celery_dispatch_completes_authoritative_job(migrated_database):
    """CI-only proof of API dispatcher -> authenticated Redis -> worker -> Postgres success."""
    if os.getenv("HONOR_TEST_CELERY_WORKER", "").lower() != "true":
        if os.getenv("GITHUB_ACTIONS", "").lower() == "true":
            pytest.fail("HONOR_TEST_CELERY_WORKER=true is mandatory in CI")
        pytest.skip("external Celery worker not started outside CI")

    async def run():
        from honor_api.dispatcher import publish_foundation_job
        from honor_api.jobs import DurableJob

        job_id, token = await _insert_job()
        job = DurableJob(
            id=job_id,
            dispatch_token=token,
            state="queued",
            stage="backup",
            version=1,
            idempotency_key=f"foundation:{job_id}",
        )
        assert publish_foundation_job(job) == job_id
        for _ in range(100):
            state = await _state(job_id)
            if state == "succeeded":
                break
            await asyncio.sleep(0.1)
        assert await _state(job_id) == "succeeded"
        assert admin_psql(
            f"SELECT count(*) FROM events WHERE job_id='{job_id}'::uuid "
            "AND event_name='JOB_SUCCEEDED'"
        ) == "1"

    asyncio.run(run())
