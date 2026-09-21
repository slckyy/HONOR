from __future__ import annotations

from .config import get_settings


async def redis_ready() -> bool:
    try:
        import redis.asyncio as redis

        client = redis.from_url(
            get_settings().redis_url,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        try:
            return bool(await client.ping())
        finally:
            await client.aclose()
    except Exception:
        return False
