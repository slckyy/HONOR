import os

from celery import Celery

pwd = os.environ["REDIS_PASSWORD"]
if len(pwd) < 32:
    raise RuntimeError("REDIS_PASSWORD must be at least 32 characters")
host = os.getenv("REDIS_HOST", "redis")
port = os.getenv("REDIS_PORT", "6379")
broker = f"redis://:{pwd}@{host}:{port}/{os.getenv('CELERY_BROKER_DB', '1')}"
backend = f"redis://:{pwd}@{host}:{port}/{os.getenv('CELERY_RESULT_DB', '2')}"
app = Celery(
    "honor",
    broker=broker,
    backend=backend,
    include=["honor_worker.tasks"],
)
app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    task_track_started=False,
    worker_prefetch_multiplier=1,
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    broker_connection_retry_on_startup=True,
    task_default_queue="foundation",
    task_routes={"honor.foundation.*": {"queue": "foundation"}},
    result_expires=3600,
)
