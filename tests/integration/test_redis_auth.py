import asyncio
import os

import pytest

URL = os.getenv("TEST_REDIS_URL")
pytestmark = pytest.mark.integration

if os.getenv("GITHUB_ACTIONS", "").lower() == "true" and not URL:
    raise RuntimeError("CI requires TEST_REDIS_URL; Redis integration tests may not silently skip")


@pytest.mark.skipif(not URL, reason="TEST_REDIS_URL not configured outside CI")
def test_redis_requires_password_and_authenticated_ping_works():
    import redis.asyncio as redis
    from redis.exceptions import AuthenticationError

    async def run():
        authenticated = redis.from_url(URL, socket_timeout=2)
        try:
            assert await authenticated.ping() is True
        finally:
            await authenticated.aclose()

        unauthenticated = redis.Redis(host="localhost", port=6379, db=0, socket_timeout=2)
        try:
            with pytest.raises(AuthenticationError):
                await unauthenticated.ping()
        finally:
            await unauthenticated.aclose()

    asyncio.run(run())
