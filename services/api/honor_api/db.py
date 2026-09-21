from __future__ import annotations

from contextlib import asynccontextmanager
from uuid import UUID

from .config import get_settings

_pool = None


async def pool():
    global _pool
    import asyncpg

    if _pool is None:
        _pool = await asyncpg.create_pool(
            get_settings().DATABASE_APP_URL,
            min_size=1,
            max_size=5,
            command_timeout=10,
            server_settings={"application_name": "honor-api"},
        )
    return _pool


@asynccontextmanager
async def owner_transaction(owner_user_id: str, request_id: str | None = None):
    """Open a runtime transaction with the frozen transaction-local owner context."""
    UUID(owner_user_id)
    if request_id is not None:
        UUID(request_id)
    database_pool = await pool()
    async with database_pool.acquire() as connection:
        transaction = connection.transaction()
        await transaction.start()
        try:
            await connection.execute(
                "SELECT set_config('honor.owner_user_id',$1,true)", owner_user_id
            )
            if request_id is not None:
                await connection.execute(
                    "SELECT set_config('honor.request_id',$1,true)", request_id
                )
            yield connection
            await transaction.commit()
        except Exception:
            await transaction.rollback()
            raise


async def owner_profile_is_active(owner_user_id: str) -> bool:
    """RLS-backed owner-profile validation required after JWT verification."""
    async with owner_transaction(owner_user_id) as connection:
        return bool(
            await connection.fetchval(
                "SELECT EXISTS(SELECT 1 FROM owner_profiles WHERE user_id=$1::uuid AND active=true)",
                owner_user_id,
            )
        )


async def database_ready() -> bool:
    try:
        database_pool = await pool()
        async with database_pool.acquire() as connection:
            return (await connection.fetchval("SELECT 1")) == 1
    except Exception:
        return False
