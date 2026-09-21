from __future__ import annotations

import asyncio
import hashlib
import json
import os
import re
from contextlib import asynccontextmanager
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Awaitable, Callable, TypeVar
from uuid import UUID, uuid5

RETRY_DELAYS_SECONDS = (30, 120, 600, 1800, 7200)
EVENT_NAMESPACE = UUID("4bd29c0c-5ac1-4cd3-afdb-a9b25ef3ac30")


class RetryableJobError(RuntimeError):
    code = "FOUNDATION_RETRYABLE"


class NonRetryableJobError(RuntimeError):
    code = "FOUNDATION_NONRETRYABLE"


class JobHeartbeatError(RetryableJobError):
    code = "JOB_HEARTBEAT_FAILED"


class OwnerActionRequired(RuntimeError):
    code = "OWNER_ACTION_REQUIRED"

    def __init__(self, message: str, owner_action_id: str):
        super().__init__(message)
        UUID(owner_action_id)
        self.owner_action_id = owner_action_id


def retry_delay(attempt: int, *, jitter_key: str | None = None) -> int:
    """Return the frozen retry base, with stable per-job ±10% jitter when keyed.

    Calling without a key exposes the canonical 30s/2m/10m/30m/2h bases for
    contract tests. Runtime transitions pass job_id so separate jobs spread out
    while a replay of the same job/attempt computes the same available_at delta.
    """
    index = max(0, min(attempt - 1, len(RETRY_DELAYS_SECONDS) - 1))
    base = RETRY_DELAYS_SECONDS[index]
    if jitter_key is None:
        return base
    digest = hashlib.sha256(f"{jitter_key}:{attempt}".encode("utf-8")).digest()
    # Map deterministically to [-1000, +1000] basis points (±10%).
    basis_points = int.from_bytes(digest[:2], "big") % 2001 - 1000
    return max(1, round(base * (10_000 + basis_points) / 10_000))


def _redact_detail(value: BaseException | str) -> str:
    text = str(value)
    text = re.sub(r"(?i)(authorization|cookie|token|key|password)=?[^\s,;]+", r"\1=[REDACTED]", text)
    text = re.sub(r"(?i)postgres(?:ql)?://[^\s]+", "[DATABASE_URL_REDACTED]", text)
    text = re.sub(r"https?://[^\s?]+\?[^\s]+", "[SIGNED_URL_REDACTED]", text)
    return text[:500]


def _event_id(key: str) -> str:
    return str(uuid5(EVENT_NAMESPACE, key))


def _event_payload(event_name: str, job_id: str, state: str, reason_code: str | None = None, evidence_id: str | None = None) -> str:
    return json.dumps(
        {
            "event_name": event_name,
            "subject_type": "job",
            "subject_id": job_id,
            "state": state,
            "reason_code": reason_code,
            "evidence_id": evidence_id,
            "amount_usd": None,
            "related_ids": [evidence_id] if evidence_id else [],
        },
        separators=(",", ":"),
        sort_keys=True,
    )


async def _connect():
    import asyncpg

    return await asyncpg.connect(os.environ["DATABASE_APP_URL"], command_timeout=30)


@asynccontextmanager
async def owner_tx(conn):
    owner_id = os.environ["HONOR_OWNER_USER_ID"]
    UUID(owner_id)
    async with conn.transaction():
        await conn.execute("SELECT set_config('honor.owner_user_id',$1,true)", owner_id)
        yield


async def _insert_job_event(conn, row: Any, event_name: str, state: str, reason_code: str | None = None, evidence_id: str | None = None) -> None:
    attempt = int(row["attempt"])
    idem = f"job:{row['id']}:{event_name}:{attempt}:{state}"
    await conn.execute(
        """
        INSERT INTO events(
          id,event_name,event_version,occurred_at,actor_type,actor_id,source_service,
          correlation_id,run_id,job_id,entity_type,entity_id,idempotency_key,payload
        ) VALUES(
          $1::uuid,$2,1,statement_timestamp(),'SYSTEM',NULL,'worker',
          $3::uuid,$4::uuid,$5::uuid,'job',$5::uuid,$6,$7::jsonb
        ) ON CONFLICT (idempotency_key) DO NOTHING
        """,
        _event_id(idem),
        event_name,
        str(row["correlation_id"]),
        str(row["run_id"]) if row["run_id"] else None,
        str(row["id"]),
        idem,
        _event_payload(event_name, str(row["id"]), state, reason_code, evidence_id),
    )


async def try_execution_lock(conn, job_id: str) -> bool:
    UUID(job_id)
    return bool(await conn.fetchval("SELECT pg_try_advisory_lock(hashtextextended($1,0))", job_id))


async def release_execution_lock(conn, job_id: str) -> None:
    await conn.execute("SELECT pg_advisory_unlock(hashtextextended($1,0))", job_id)


async def claim_job_on_connection(conn, job_id: str, dispatch_token: str) -> dict[str, Any] | None:
    UUID(job_id)
    UUID(dispatch_token)
    async with owner_tx(conn):
        row = await conn.fetchrow("SELECT * FROM jobs WHERE id=$1::uuid FOR UPDATE", job_id)
        if row is None or str(row["dispatch_token"]) != dispatch_token:
            return None
        if str(row["state"]) != "queued" or row["available_at"] > datetime.now(timezone.utc):
            return None
        claimed = await conn.fetchrow(
            """
            UPDATE jobs
               SET state='running', attempt=attempt+1,
                   started_at=COALESCE(started_at,statement_timestamp()),
                   heartbeat_at=statement_timestamp(),
                   lease_expires_at=statement_timestamp() + make_interval(secs=>timeout_seconds),
                   failure_code=NULL,failure_detail_redacted=NULL,
                   version=version+1, updated_at=statement_timestamp()
             WHERE id=$1::uuid
            RETURNING *
            """,
            job_id,
        )
        return dict(claimed)


async def heartbeat_on_connection(conn, job_id: str, dispatch_token: str) -> bool:
    async with owner_tx(conn):
        result = await conn.execute(
            """
            UPDATE jobs
               SET heartbeat_at=statement_timestamp(),
                   lease_expires_at=statement_timestamp() + make_interval(secs=>timeout_seconds),
                   updated_at=statement_timestamp()
             WHERE id=$1::uuid AND dispatch_token=$2::uuid AND state='running'
            """,
            job_id,
            dispatch_token,
        )
    return result.endswith("1")


T = TypeVar("T")
MAX_JOB_HEARTBEAT_INTERVAL_SECONDS = 30.0
DEFAULT_JOB_HEARTBEAT_INTERVAL_SECONDS = 20.0


def job_heartbeat_interval_seconds() -> float:
    raw = os.getenv("HONOR_JOB_HEARTBEAT_INTERVAL_SECONDS", str(DEFAULT_JOB_HEARTBEAT_INTERVAL_SECONDS))
    try:
        value = float(raw)
    except ValueError as exc:
        raise RuntimeError("HONOR_JOB_HEARTBEAT_INTERVAL_SECONDS must be numeric") from exc
    if value <= 0:
        raise RuntimeError("HONOR_JOB_HEARTBEAT_INTERVAL_SECONDS must be positive")
    return min(value, MAX_JOB_HEARTBEAT_INTERVAL_SECONDS)


async def _heartbeat_loop(job_id: str, dispatch_token: str, stop: asyncio.Event, *, interval: float, connection_factory=_connect) -> None:
    conn = await connection_factory()
    try:
        while True:
            try:
                await asyncio.wait_for(stop.wait(), timeout=interval)
                return
            except asyncio.TimeoutError:
                pass
            if not await heartbeat_on_connection(conn, job_id, dispatch_token):
                raise JobHeartbeatError("running job heartbeat renewal was rejected")
    finally:
        await conn.close()


async def run_with_job_heartbeat(
    job_id: str,
    dispatch_token: str,
    work: Callable[[], Awaitable[T]],
    *,
    interval: float | None = None,
    connection_factory=_connect,
) -> T:
    """Run claimed work while a separate PostgreSQL session renews its lease."""
    cadence = job_heartbeat_interval_seconds() if interval is None else min(float(interval), MAX_JOB_HEARTBEAT_INTERVAL_SECONDS)
    if cadence <= 0:
        raise RuntimeError("heartbeat interval must be positive")
    stop = asyncio.Event()
    heartbeat_task = asyncio.create_task(
        _heartbeat_loop(job_id, dispatch_token, stop, interval=cadence, connection_factory=connection_factory),
        name=f"honor-job-heartbeat:{job_id}",
    )
    work_task = asyncio.create_task(work(), name=f"honor-job-work:{job_id}")
    try:
        done, _ = await asyncio.wait({work_task, heartbeat_task}, return_when=asyncio.FIRST_COMPLETED)
        if heartbeat_task in done and work_task not in done:
            exc = heartbeat_task.exception()
            work_task.cancel()
            try:
                await work_task
            except asyncio.CancelledError:
                pass
            if isinstance(exc, JobHeartbeatError):
                raise exc
            if exc is None:
                raise JobHeartbeatError("heartbeat loop stopped before work completed")
            raise JobHeartbeatError(f"heartbeat renewal failed: {type(exc).__name__}") from exc
        result = await work_task
        return result
    finally:
        stop.set()
        if not heartbeat_task.done():
            await heartbeat_task
        elif not heartbeat_task.cancelled():
            exc = heartbeat_task.exception()
            if exc is not None and work_task.done() and not work_task.cancelled() and work_task.exception() is None:
                raise exc


async def execute_durable_job(
    job_id: str,
    dispatch_token: str,
    work: Callable[[], Awaitable[T]],
) -> dict[str, Any]:
    """Generic C01 durable execution wrapper inherited by later job implementations."""
    conn = await _connect()
    locked = False
    try:
        locked = await try_execution_lock(conn, job_id)
        if not locked:
            return {"ok": True, "duplicate_or_ineligible": True, "job_id": job_id}
        claimed = await claim_job_on_connection(conn, job_id, dispatch_token)
        if claimed is None:
            return {"ok": True, "duplicate_or_ineligible": True, "job_id": job_id}
        try:
            result = await run_with_job_heartbeat(job_id, dispatch_token, work)
            if not await succeed_on_connection(conn, job_id, dispatch_token):
                raise RuntimeError("job became ineligible before success transition")
            return {"ok": True, "duplicate_or_ineligible": False, "job_id": job_id, "attempt": claimed["attempt"], "state": "succeeded", "result": result}
        except OwnerActionRequired as exc:
            state = await fail_on_connection(conn, job_id, dispatch_token, code=exc.code, detail=exc, retryable=False, owner_action_id=exc.owner_action_id)
            return {"ok": False, "job_id": job_id, "state": state}
        except NonRetryableJobError as exc:
            state = await fail_on_connection(conn, job_id, dispatch_token, code=exc.code, detail=exc, retryable=False)
            return {"ok": False, "job_id": job_id, "state": state}
        except Exception as exc:
            code = exc.code if isinstance(exc, RetryableJobError) else "FOUNDATION_UNHANDLED_ERROR"
            state = await fail_on_connection(conn, job_id, dispatch_token, code=code, detail=exc, retryable=True)
            return {"ok": False, "job_id": job_id, "state": state}
    finally:
        if locked:
            await release_execution_lock(conn, job_id)
        await conn.close()


async def succeed_on_connection(conn, job_id: str, dispatch_token: str) -> bool:
    async with owner_tx(conn):
        row = await conn.fetchrow(
            "SELECT * FROM jobs WHERE id=$1::uuid AND dispatch_token=$2::uuid FOR UPDATE",
            job_id,
            dispatch_token,
        )
        if row is None or str(row["state"]) != "running":
            return False
        row = await conn.fetchrow(
            """
            UPDATE jobs
               SET state='succeeded', finished_at=statement_timestamp(),
                   heartbeat_at=statement_timestamp(), lease_expires_at=NULL,
                   failure_code=NULL,failure_detail_redacted=NULL,
                   version=version+1, updated_at=statement_timestamp()
             WHERE id=$1::uuid RETURNING *
            """,
            job_id,
        )
        await _insert_job_event(conn, row, "JOB_SUCCEEDED", "succeeded")
        return True


async def fail_on_connection(
    conn,
    job_id: str,
    dispatch_token: str,
    *,
    code: str,
    detail: str,
    retryable: bool,
    owner_action_id: str | None = None,
) -> str:
    async with owner_tx(conn):
        row = await conn.fetchrow(
            "SELECT * FROM jobs WHERE id=$1::uuid AND dispatch_token=$2::uuid FOR UPDATE",
            job_id,
            dispatch_token,
        )
        if row is None or str(row["state"]) != "running":
            return "ineligible"
        attempt = int(row["attempt"])
        if owner_action_id is not None:
            UUID(owner_action_id)
            updated = await conn.fetchrow(
                """
                UPDATE jobs SET state='blocked-owner-action',owner_action_id=$2::uuid,
                  failure_code=$3,failure_detail_redacted=$4,lease_expires_at=NULL,
                  version=version+1,updated_at=statement_timestamp()
                WHERE id=$1::uuid RETURNING *
                """,
                job_id,
                owner_action_id,
                code,
                _redact_detail(detail),
            )
            await _insert_job_event(conn, updated, "OWNER_ACTION_REQUIRED", "blocked-owner-action", code, owner_action_id)
            return "blocked-owner-action"
        if retryable and attempt < int(row["max_attempts"]):
            delay = retry_delay(attempt, jitter_key=job_id)
            updated = await conn.fetchrow(
                """
                UPDATE jobs SET state='retrying',available_at=statement_timestamp()+make_interval(secs=>$2),
                  failure_code=$3,failure_detail_redacted=$4,lease_expires_at=NULL,
                  version=version+1,updated_at=statement_timestamp()
                WHERE id=$1::uuid RETURNING *
                """,
                job_id,
                delay,
                code,
                _redact_detail(detail),
            )
            await _insert_job_event(conn, updated, "JOB_RETRY_SCHEDULED", "retrying", code)
            return "retrying"
        updated = await conn.fetchrow(
            """
            UPDATE jobs SET state='failed-terminal',finished_at=statement_timestamp(),
              failure_code=$2,failure_detail_redacted=$3,lease_expires_at=NULL,
              version=version+1,updated_at=statement_timestamp()
            WHERE id=$1::uuid RETURNING *
            """,
            job_id,
            code,
            _redact_detail(detail),
        )
        await _insert_job_event(conn, updated, "JOB_FAILED_TERMINAL", "failed-terminal", code)
        return "failed-terminal"


async def execute_foundation_job(job_id: str, dispatch_token: str) -> dict[str, Any]:
    """Narrow C01 proof task through the generic heartbeat-aware wrapper."""
    async def foundation_work() -> dict[str, bool]:
        delay=max(0.0,float(os.getenv("HONOR_FOUNDATION_TASK_SECONDS","0")))
        if delay:
            await asyncio.sleep(delay)
        return {"foundation": True}
    return await execute_durable_job(job_id, dispatch_token, foundation_work)


def execute_foundation_job_sync(job_id: str, dispatch_token: str) -> dict[str, Any]:
    return asyncio.run(execute_foundation_job(job_id, dispatch_token))
