FROM python:3.13.15-slim
WORKDIR /app
COPY requirements.lock /app/requirements.lock
RUN pip install --no-cache-dir -r /app/requirements.lock
COPY services/api /app/services/api
COPY packages/contracts /app/packages/contracts
COPY scripts/migrate.py /app/scripts/migrate.py
COPY scripts/provision_runtime_role.py /app/scripts/provision_runtime_role.py
COPY infrastructure/migrations /app/infrastructure/migrations
ENV PYTHONPATH=/app/services/api PYTHONDONTWRITEBYTECODE=1
USER 65532:65532
CMD ["uvicorn","honor_api.app:app","--host","0.0.0.0","--port","8000"]
