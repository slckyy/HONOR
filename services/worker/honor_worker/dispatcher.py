from __future__ import annotations

from .celery_app import app


def publish_job(job_id: str, dispatch_token: str) -> str:
    result = app.send_task(
        "honor.foundation.echo",
        kwargs={"job_id": job_id, "dispatch_token": dispatch_token},
        task_id=job_id,
        queue="foundation",
    )
    return str(result.id)
