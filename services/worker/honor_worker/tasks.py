from .celery_app import app
from .durable_jobs import execute_foundation_job_sync


@app.task(name="honor.foundation.echo", bind=True, acks_late=True)
def foundation_echo(self, job_id: str, dispatch_token: str) -> dict:
    """Broker payload is durable identity only; PostgreSQL decides whether work may run."""
    return execute_foundation_job_sync(job_id, dispatch_token)
