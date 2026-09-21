from __future__ import annotations

import logging
from time import monotonic
from uuid import UUID, uuid4

from fastapi import Request

from .config import get_settings
from .logging import log_event

logger = logging.getLogger("honor.api")


async def request_context(request: Request, call_next):
    incoming = request.headers.get("x-request-id")
    try:
        request_id = str(UUID(incoming)) if incoming else str(uuid4())
    except (ValueError, TypeError):
        request_id = str(uuid4())
    request.state.request_id = request_id
    request.state.actor_id = None
    started = monotonic()
    try:
        response = await call_next(request)
    except Exception:
        log_event(
            logger,
            service="api",
            environment=get_settings().HONOR_ENV,
            request_id=request_id,
            actor_id=getattr(request.state, "actor_id", None),
            event_code="HTTP_UNHANDLED_ERROR",
            severity="ERROR",
            metadata={"method": request.method, "path": request.url.path},
        )
        raise
    response.headers["X-Request-ID"] = request_id
    log_event(
        logger,
        service="api",
        environment=get_settings().HONOR_ENV,
        request_id=request_id,
        actor_id=getattr(request.state, "actor_id", None),
        event_code="HTTP_REQUEST_COMPLETED",
        severity="INFO",
        metadata={
            "method": request.method,
            "path": request.url.path,
            "status": response.status_code,
            "duration_ms": round((monotonic() - started) * 1000),
        },
    )
    return response
