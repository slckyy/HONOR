"""Post-commit broker dispatcher. PostgreSQL remains authoritative job truth."""
from __future__ import annotations

from celery import Celery

from .config import get_settings
from .jobs import DurableJob, dispatch_payload


def _celery() -> Celery:
    settings = get_settings()
    broker = (
        f"redis://:{settings.REDIS_PASSWORD}@{settings.REDIS_HOST}:"
        f"{settings.REDIS_PORT}/{settings.CELERY_BROKER_DB}"
    )
    return Celery("honor-api-dispatch", broker=broker)


def publish_foundation_job(job: DurableJob) -> str:
    payload = dispatch_payload(job)
    result = _celery().send_task(
        "honor.foundation.echo",
        kwargs=payload,
        task_id=job.celery_task_id,
        queue="foundation",
    )
    return str(result.id)
