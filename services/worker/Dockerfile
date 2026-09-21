FROM python:3.13.15-slim
WORKDIR /app
COPY requirements.lock /app/requirements.lock
RUN pip install --no-cache-dir -r /app/requirements.lock
COPY services/worker /app/services/worker
COPY infrastructure/monitoring/worker-heartbeat.sh /app/infrastructure/monitoring/worker-heartbeat.sh
ENV PYTHONPATH=/app/services/worker PYTHONDONTWRITEBYTECODE=1
USER 65532:65532
CMD ["celery","-A","honor_worker.celery_app:app","worker","--loglevel=INFO","--concurrency=1"]
