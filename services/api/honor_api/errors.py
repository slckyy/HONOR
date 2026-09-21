from __future__ import annotations

from fastapi import HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class HonorError(Exception):
    def __init__(
        self,
        status: int,
        code: str,
        message: str,
        details: dict | None = None,
    ):
        self.status = status
        self.code = code
        self.message = message
        self.details = details or {}


def _request_id(request: Request) -> str:
    return getattr(
        request.state,
        "request_id",
        "00000000-0000-0000-0000-000000000000",
    )


def error_response(
    request: Request,
    *,
    status: int,
    code: str,
    message: str,
    details: dict | None = None,
) -> JSONResponse:
    return JSONResponse(
        status_code=status,
        content={
            "error": {
                "code": code,
                "message": message,
                "request_id": _request_id(request),
                "details": details or {},
            }
        },
        headers={"Cache-Control": "private, no-store"},
    )


async def honor_error_handler(request: Request, exc: HonorError):
    return error_response(
        request,
        status=exc.status,
        code=exc.code,
        message=exc.message,
        details=exc.details,
    )


async def validation_error_handler(request: Request, exc: RequestValidationError):
    details = {
        "fields": [
            {"location": [str(v) for v in item["loc"]], "type": item["type"]}
            for item in exc.errors()
        ]
    }
    return error_response(
        request,
        status=422,
        code="VALIDATION_ERROR",
        message="Request validation failed.",
        details=details,
    )


async def http_error_handler(request: Request, exc: HTTPException):
    code = "NOT_FOUND" if exc.status_code == 404 else "HTTP_ERROR"
    return error_response(
        request,
        status=exc.status_code,
        code=code,
        message="Request failed.",
    )


async def unhandled_error_handler(request: Request, exc: Exception):
    del exc
    return error_response(
        request,
        status=500,
        code="INTERNAL_ERROR",
        message="Internal server error.",
    )
