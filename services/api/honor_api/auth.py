from __future__ import annotations

from uuid import UUID

import jwt
from fastapi import Header, Request
from jwt import PyJWKClient
from jwt.exceptions import PyJWKClientConnectionError, PyJWKClientError

from .config import get_settings
from .db import owner_profile_is_active
from .errors import HonorError
from .logging import safe_actor_id

_jwks: dict[str, PyJWKClient] = {}


def _client(url: str) -> PyJWKClient:
    if url not in _jwks:
        # Frozen cache maximum is 10 minutes; C01 uses five minutes.
        _jwks[url] = PyJWKClient(url, cache_keys=True, lifespan=300, timeout=5)
    return _jwks[url]


def validate_owner_token(token: str) -> str:
    settings = get_settings()
    issuer = settings.SUPABASE_URL.rstrip("/") + "/auth/v1"
    try:
        key = _client(settings.SUPABASE_JWKS_URL).get_signing_key_from_jwt(token).key
        claims = jwt.decode(
            token,
            key,
            algorithms=["RS256", "ES256"],
            audience="authenticated",
            issuer=issuer,
            leeway=30,
            options={"require": ["sub", "iss", "aud", "exp"]},
        )
    except PyJWKClientConnectionError as exc:
        raise HonorError(
            503,
            "AUTH_PROVIDER_UNAVAILABLE",
            "Authentication provider is temporarily unavailable.",
        ) from exc
    except PyJWKClientError as exc:
        raise HonorError(401, "AUTH_INVALID", "Authentication token is invalid.") from exc
    except jwt.PyJWTError as exc:
        raise HonorError(401, "AUTH_INVALID", "Authentication token is invalid.") from exc

    sub = str(claims.get("sub", ""))
    try:
        UUID(sub)
    except ValueError as exc:
        raise HonorError(401, "AUTH_INVALID", "Authentication token is invalid.") from exc
    if sub != settings.HONOR_OWNER_USER_ID:
        raise HonorError(
            403,
            "OWNER_FORBIDDEN",
            "Authenticated user is not the configured HONOR owner.",
        )
    return sub


async def require_owner(
    request: Request,
    authorization: str | None = Header(default=None),
) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise HonorError(401, "AUTH_REQUIRED", "Owner authentication required.")
    owner_user_id = validate_owner_token(authorization[7:])
    try:
        active = await owner_profile_is_active(owner_user_id)
    except HonorError:
        raise
    except Exception as exc:
        raise HonorError(
            503,
            "PROVIDER_UNAVAILABLE",
            "Owner authorization database is unavailable.",
        ) from exc
    if not active:
        raise HonorError(
            403,
            "OWNER_FORBIDDEN",
            "Authenticated user is not an active HONOR owner.",
        )
    request.state.actor_id = safe_actor_id(owner_user_id)
    return owner_user_id
