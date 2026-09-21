from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import json
from pathlib import Path
from typing import Any
from uuid import UUID, uuid5

from jsonschema import Draft202012Validator, FormatChecker

from .db import owner_transaction

JOB_NAMESPACE = UUID("b19f5c48-1e3c-4c73-9a59-5dc847ae9d8d")
DISPATCH_NAMESPACE = UUID("fa6f3458-037a-42e0-88f4-8151abbbfe7d")
EVENT_NAMESPACE = UUID("4bd29c0c-5ac1-4cd3-afdb-a9b25ef3ac30")

ALLOWED = {
    "queued": {"running", "cancelled"},
    "running": {"succeeded", "retrying", "blocked-owner-action", "failed-terminal", "cancelled"},
    "retrying": {"queued", "failed-terminal", "cancelled"},
    "blocked-owner-action": {"queued", "cancelled"},
    "failed-terminal": set(),
    "succeeded": set(),
    "cancelled": set(),
}

VALID_STAGES = {
    "campaign_import",
    "rules_normalization",
    "source_ingest",
    "rights_verification",
    "transcription",
    "candidate_discovery",
    "candidate_scoring",
    "finalist_selection",
    "edit_plan",
    "audio_plan",
    "render",
    "qc",
    "schedule",
    "analytics_ingest",
    "payout_reconcile",
    "cost_reconcile",
    "backup",
}

ROOT = Path(__file__).resolve().parents[3]
_EVENT_SCHEMA = json.loads((ROOT / "packages/contracts/jsonschema/event.payload.v1.json").read_text())
_EVENT_VALIDATOR = Draft202012Validator(_EVENT_SCHEMA, format_checker=FormatChecker())


def deterministic_job_id(job_type: str, idempotency_key: str) -> str:
    return str(uuid5(JOB_NAMESPACE, f"{job_type}:{idempotency_key}"))


def deterministic_dispatch_token(job_id: str) -> str:
    UUID(job_id)
    return str(uuid5(DISPATCH_NAMESPACE, job_id))


def deterministic_event_id(idempotency_key: str) -> str:
    return str(uuid5(EVENT_NAMESPACE, idempotency_key))


def assert_job_transition(old: str, new: str) -> None:
    if new not in ALLOWED.get(old, set()):
        raise ValueError(f"invalid job transition {old}->{new}")


@dataclass(frozen=True)
class JobSpec:
    job_type: str
    domain_entity_type: str
    domain_entity_id: str
    stage: str
    idempotency_key: str
    correlation_id: str
    max_attempts: int = 5
    timeout_seconds: int = 900
    run_id: str | None = None

    def validate(self) -> None:
        if self.stage not in VALID_STAGES:
            raise ValueError(f"unsupported job stage: {self.stage}")
        UUID(self.domain_entity_id)
        UUID(self.correlation_id)
        if self.run_id is not None:
            UUID(self.run_id)
        if not self.idempotency_key or len(self.idempotency_key) > 500:
            raise ValueError("invalid idempotency key")
        if self.max_attempts < 1:
            raise ValueError("max_attempts must be >= 1")
        if self.timeout_seconds <= 0:
            raise ValueError("timeout_seconds must be > 0")


@dataclass(frozen=True)
class DurableJob:
    id: str
    dispatch_token: str
    state: str
    stage: str
    version: int
    idempotency_key: str

    @property
    def celery_task_id(self) -> str:
        # The task ID is deterministic and equal to the durable Postgres job ID.
        return self.id


class DurableJobStore:
    """Postgres is authoritative; Redis/Celery is only a post-commit dispatcher."""

    async def enqueue(
        self,
        owner_user_id: str,
        spec: JobSpec,
        *,
        event_name: str,
        event_payload: dict[str, Any],
        actor_type: str = "SYSTEM",
        source_service: str = "api",
    ) -> DurableJob:
        spec.validate()
        _EVENT_VALIDATOR.validate(event_payload)
        if event_payload.get("event_name") != event_name:
            raise ValueError("event payload event_name mismatch")

        job_id = deterministic_job_id(spec.job_type, spec.idempotency_key)
        dispatch_token = deterministic_dispatch_token(job_id)
        event_idempotency_key = f"job-enqueue:{spec.idempotency_key}:{event_name}"
        event_id = deterministic_event_id(event_idempotency_key)
        occurred_at = datetime.now(timezone.utc)

        async with owner_transaction(owner_user_id) as connection:
            row = await connection.fetchrow(
                """
                INSERT INTO jobs(
                    id, job_type, domain_entity_type, domain_entity_id, state, stage,
                    attempt, max_attempts, idempotency_key, dispatch_token, correlation_id,
                    run_id, timeout_seconds
                ) VALUES(
                    $1::uuid,$2,$3,$4::uuid,'queued',$5,0,$6,$7,$8::uuid,$9::uuid,$10::uuid,$11
                )
                ON CONFLICT (idempotency_key) DO NOTHING
                RETURNING id::text,dispatch_token::text,state::text,stage,version,idempotency_key
                """,
                job_id,
                spec.job_type,
                spec.domain_entity_type,
                spec.domain_entity_id,
                spec.stage,
                spec.max_attempts,
                spec.idempotency_key,
                dispatch_token,
                spec.correlation_id,
                spec.run_id,
                spec.timeout_seconds,
            )
            if row is None:
                row = await connection.fetchrow(
                    """
                    SELECT id::text,dispatch_token::text,state::text,stage,version,idempotency_key,
                           job_type,domain_entity_type,domain_entity_id::text,correlation_id::text,
                           run_id::text,max_attempts,timeout_seconds
                    FROM jobs WHERE idempotency_key=$1
                    """,
                    spec.idempotency_key,
                )
                if row is None:
                    raise RuntimeError("idempotent job lookup failed")
                expected = {
                    "id": job_id,
                    "dispatch_token": dispatch_token,
                    "job_type": spec.job_type,
                    "domain_entity_type": spec.domain_entity_type,
                    "domain_entity_id": spec.domain_entity_id,
                    "stage": spec.stage,
                    "correlation_id": spec.correlation_id,
                    "run_id": spec.run_id,
                    "max_attempts": spec.max_attempts,
                    "timeout_seconds": spec.timeout_seconds,
                }
                mismatches = [key for key, value in expected.items() if row[key] != value]
                if mismatches:
                    raise RuntimeError(
                        "idempotency key reused with different job semantics: "
                        + ",".join(sorted(mismatches))
                    )
            else:
                await connection.execute(
                    """
                    INSERT INTO events(
                        id,event_name,event_version,occurred_at,actor_type,actor_id,
                        source_service,correlation_id,run_id,job_id,entity_type,entity_id,
                        idempotency_key,payload
                    ) VALUES(
                        $1::uuid,$2,1,$3,$4,NULL,$5,$6::uuid,$7::uuid,$8::uuid,$9,$10::uuid,$11,$12::jsonb
                    )
                    ON CONFLICT (idempotency_key) DO NOTHING
                    """,
                    event_id,
                    event_name,
                    occurred_at,
                    actor_type,
                    source_service,
                    spec.correlation_id,
                    spec.run_id,
                    job_id,
                    spec.domain_entity_type,
                    spec.domain_entity_id,
                    event_idempotency_key,
                    json.dumps(event_payload, separators=(",", ":"), sort_keys=True),
                )

        return DurableJob(
            id=row["id"],
            dispatch_token=row["dispatch_token"],
            state=row["state"],
            stage=row["stage"],
            version=row["version"],
            idempotency_key=row["idempotency_key"],
        )

    async def enqueue_and_dispatch(self, owner_user_id: str, spec: JobSpec, **kwargs) -> DurableJob:
        """Commit durable truth first, then best-effort publish only its durable identity."""
        job = await self.enqueue(owner_user_id, spec, **kwargs)
        if job.state == "queued":
            from .dispatcher import publish_foundation_job
            publish_foundation_job(job)
        return job

    async def dispatchable(self, owner_user_id: str, job_id: str, dispatch_token: str) -> bool:
        UUID(job_id)
        UUID(dispatch_token)
        async with owner_transaction(owner_user_id) as connection:
            return bool(
                await connection.fetchval(
                    """
                    SELECT EXISTS(
                        SELECT 1 FROM jobs
                        WHERE id=$1::uuid AND dispatch_token=$2::uuid
                          AND state IN ('queued','retrying') AND available_at<=statement_timestamp()
                    )
                    """,
                    job_id,
                    dispatch_token,
                )
            )


def dispatch_payload(job: DurableJob) -> dict[str, str]:
    """The only broker payload needed to re-acquire authoritative state from Postgres."""
    return {"job_id": job.id, "dispatch_token": job.dispatch_token}
