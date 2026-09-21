from __future__ import annotations

from datetime import datetime, timezone

from fastapi import Depends, FastAPI, HTTPException
from fastapi.exceptions import RequestValidationError

from .auth import require_owner
from .c02_api import router as c02_router
from .db import database_ready
from .errors import (
    HonorError,
    honor_error_handler,
    http_error_handler,
    unhandled_error_handler,
    validation_error_handler,
)
from .redis_client import redis_ready
from .request_context import request_context
from .storage import storage_ready


def create_app() -> FastAPI:
    app = FastAPI(
        title="HONOR V1 Internal API",
        version="0.2.0-c02",
        docs_url=None,
        redoc_url=None,
        openapi_url=None,
    )
    app.middleware("http")(request_context)
    app.add_exception_handler(HonorError, honor_error_handler)
    app.add_exception_handler(RequestValidationError, validation_error_handler)
    app.add_exception_handler(HTTPException, http_error_handler)
    app.add_exception_handler(Exception, unhandled_error_handler)
    app.include_router(c02_router)

    @app.get("/healthz")
    async def healthz():
        return {
            "status": "ok",
            "service": "honor-api",
            "time": datetime.now(timezone.utc).isoformat(),
        }

    @app.get("/readyz")
    async def readyz(owner: str = Depends(require_owner)):
        del owner
        checks = {
            "database": "ok" if await database_ready() else "error",
            "redis": "ok" if await redis_ready() else "error",
            "r2": "ok" if storage_ready() else "error",
        }
        if "error" in checks.values():
            raise HonorError(
                503,
                "PROVIDER_UNAVAILABLE",
                "One or more required dependencies are unavailable.",
                {"checks": checks},
            )
        return {
            "status": "ready",
            "time": datetime.now(timezone.utc).isoformat(),
            "checks": checks,
        }

    return app


app = create_app()
