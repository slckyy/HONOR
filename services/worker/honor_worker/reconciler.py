from __future__ import annotations

import asyncio
import os
from dataclasses import dataclass
from uuid import UUID

from .durable_jobs import _insert_job_event, owner_tx, retry_delay

LEADER_LOCK_KEY = int.from_bytes(b"HONORREC", "big", signed=False)


@dataclass
class ReconcileStats:
    leader: bool = False
    retrying_to_queued: int = 0
    expired_to_retrying: int = 0
    expired_to_terminal: int = 0
    published: int = 0
    active_lease_skipped: int = 0


async def _recover_expired(conn, stats: ReconcileStats) -> None:
    async with owner_tx(conn):
        candidates = await conn.fetch(
            """
            SELECT id::text FROM jobs
             WHERE state='running' AND lease_expires_at IS NOT NULL
               AND lease_expires_at < statement_timestamp()
             ORDER BY lease_expires_at,id
            """
        )
    for candidate in candidates:
        job_id = candidate["id"]
        acquired = bool(await conn.fetchval("SELECT pg_try_advisory_lock(hashtextextended($1,0))", job_id))
        if not acquired:
            stats.active_lease_skipped += 1
            continue
        try:
            async with owner_tx(conn):
                row = await conn.fetchrow("SELECT * FROM jobs WHERE id=$1::uuid FOR UPDATE", job_id)
                if row is None or str(row["state"]) != "running" or row["lease_expires_at"] is None:
                    continue
                still_expired = await conn.fetchval("SELECT $1::timestamptz < statement_timestamp()", row["lease_expires_at"])
                if not still_expired:
                    continue
                if int(row["attempt"]) >= int(row["max_attempts"]):
                    updated = await conn.fetchrow(
                        """
                        UPDATE jobs SET state='failed-terminal',finished_at=statement_timestamp(),
                          failure_code='LEASE_EXPIRED',failure_detail_redacted='worker lease expired',
                          lease_expires_at=NULL,version=version+1,updated_at=statement_timestamp()
                        WHERE id=$1::uuid RETURNING *
                        """,
                        job_id,
                    )
                    await _insert_job_event(conn, updated, "JOB_FAILED_TERMINAL", "failed-terminal", "LEASE_EXPIRED")
                    stats.expired_to_terminal += 1
                else:
                    delay = retry_delay(int(row["attempt"]), jitter_key=job_id)
                    updated = await conn.fetchrow(
                        """
                        UPDATE jobs SET state='retrying',available_at=statement_timestamp()+make_interval(secs=>$2),
                          failure_code='LEASE_EXPIRED',failure_detail_redacted='worker lease expired',
                          lease_expires_at=NULL,version=version+1,updated_at=statement_timestamp()
                        WHERE id=$1::uuid RETURNING *
                        """,
                        job_id,
                        delay,
                    )
                    await _insert_job_event(conn, updated, "JOB_RETRY_SCHEDULED", "retrying", "LEASE_EXPIRED")
                    stats.expired_to_retrying += 1
        finally:
            await conn.execute("SELECT pg_advisory_unlock(hashtextextended($1,0))", job_id)


async def reconcile_once(*, publisher=None) -> ReconcileStats:
    import asyncpg
    if publisher is None:
        from .dispatcher import publish_job
        publisher = publish_job

    owner = os.environ["HONOR_OWNER_USER_ID"]
    UUID(owner)
    conn = await asyncpg.connect(os.environ["DATABASE_APP_URL"], command_timeout=30)
    stats = ReconcileStats()
    leader = False
    try:
        leader = bool(await conn.fetchval("SELECT pg_try_advisory_lock($1::bigint)", LEADER_LOCK_KEY))
        if not leader:
            return stats
        stats.leader = True
        await _recover_expired(conn, stats)
        transitioned = []
        async with owner_tx(conn):
            due = await conn.fetch(
                """
                SELECT id::text FROM jobs
                 WHERE state='retrying' AND available_at<=statement_timestamp()
                 ORDER BY available_at,id FOR UPDATE SKIP LOCKED
                """
            )
            for row in due:
                updated = await conn.fetchrow(
                    """
                    UPDATE jobs SET state='queued',heartbeat_at=NULL,lease_expires_at=NULL,
                      version=version+1,updated_at=statement_timestamp()
                    WHERE id=$1::uuid AND state='retrying'
                    RETURNING id::text,dispatch_token::text
                    """,
                    row["id"],
                )
                if updated is not None:
                    stats.retrying_to_queued += 1
                    transitioned.append(updated)

        # Newly-due retries are published once immediately after their durable transition commits.
        for row in transitioned:
            publisher(row["id"], row["dispatch_token"])
            stats.published += 1

        # Broker-loss recovery only republishes *old* queued work. The updated_at touch after a
        # successful publish throttles repeated delivery while keeping PostgreSQL authoritative.
        redispatch_age = max(15, int(os.getenv("HONOR_REDISPATCH_MIN_AGE_SECONDS", "30")))
        async with owner_tx(conn):
            queued = await conn.fetch(
                """
                SELECT id::text,dispatch_token::text FROM jobs
                 WHERE state='queued' AND available_at<=statement_timestamp()
                   AND updated_at<=statement_timestamp()-make_interval(secs=>$1)
                 ORDER BY available_at,id
                """,
                redispatch_age,
            )
        for row in queued:
            publisher(row["id"], row["dispatch_token"])
            stats.published += 1
            async with owner_tx(conn):
                await conn.execute(
                    """
                    UPDATE jobs SET updated_at=statement_timestamp()
                     WHERE id=$1::uuid AND dispatch_token=$2::uuid AND state='queued'
                    """,
                    row["id"],
                    row["dispatch_token"],
                )
        return stats
    finally:
        if leader:
            await conn.execute("SELECT pg_advisory_unlock($1::bigint)", LEADER_LOCK_KEY)
        await conn.close()


async def publish_reconciler_liveness() -> None:
    import redis.asyncio as redis
    pwd=os.environ["REDIS_PASSWORD"]
    host=os.getenv("REDIS_HOST","redis")
    port=os.getenv("REDIS_PORT","6379")
    db=os.getenv("REDIS_CACHE_DB","0")
    ttl=max(45,int(os.getenv("HONOR_RECONCILER_HEALTH_TTL_SECONDS","75")))
    client=redis.from_url(f"redis://:{pwd}@{host}:{port}/{db}")
    try:
        await client.set("honor:health:reconciler","ok",ex=ttl)
    finally:
        await client.aclose()


async def _main() -> None:
    interval = max(5, int(os.getenv("HONOR_RECONCILE_INTERVAL_SECONDS", "15")))
    while True:
        try:
            await reconcile_once()
            await publish_reconciler_liveness()
        except Exception as exc:  # service supervisor restarts on fatal process failure; loop tolerates transient DB/Redis loss
            print(f'{{"service":"reconciler","severity":"ERROR","event_code":"RECONCILE_FAILED","error_type":"{type(exc).__name__}"}}', flush=True)
        await asyncio.sleep(interval)


if __name__ == "__main__":
    asyncio.run(_main())
