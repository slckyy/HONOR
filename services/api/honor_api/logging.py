from __future__ import annotations

import hashlib
import json
import logging
import re
from datetime import datetime, timezone

SECRET_KEYS = re.compile(
    r"(authorization|cookie|password|secret|api[_-]?key|token|jwt|database.*url|presigned)",
    re.I,
)
SECRET_VALUE_PATTERNS = [
    re.compile(r"Bearer\s+[^\s]+", re.I),
    re.compile(r"postgres(?:ql)?://[^\s]+", re.I),
    re.compile(r"sk-[A-Za-z0-9_-]{16,}"),
    re.compile(r"(?:aws|r2)[_-]?(?:secret|access)[_-]?key[^\s,;]*", re.I),
]


def safe_actor_id(owner_user_id: str) -> str:
    return "owner:" + hashlib.sha256(owner_user_id.encode("utf-8")).hexdigest()[:16]


def redact(value):
    if isinstance(value, dict):
        return {
            k: ("[REDACTED]" if SECRET_KEYS.search(str(k)) else redact(v))
            for k, v in value.items()
        }
    if isinstance(value, list):
        return [redact(v) for v in value]
    if isinstance(value, tuple):
        return tuple(redact(v) for v in value)
    if isinstance(value, str):
        out = value
        for pattern in SECRET_VALUE_PATTERNS:
            out = pattern.sub("[REDACTED]", out)
        return out
    return value


def log_event(
    logger: logging.Logger,
    *,
    service: str = "api",
    environment: str = "development",
    request_id=None,
    job_id=None,
    actor_id=None,
    event_code: str = "EVENT",
    severity: str = "INFO",
    metadata=None,
):
    payload = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": service,
        "environment": environment,
        "request_id": request_id,
        "job_id": job_id,
        "actor_id": actor_id,
        "event_code": event_code,
        "severity": severity,
        "metadata": redact(metadata or {}),
    }
    getattr(logger, severity.lower(), logger.info)(
        json.dumps(payload, separators=(",", ":"), sort_keys=True)
    )
