#!/usr/bin/env python3
from __future__ import annotations
import asyncio, os

async def main() -> None:
    import asyncpg
    admin_url=os.environ.get("DATABASE_ADMIN_URL")
    password=os.environ.get("HONOR_APP_DB_PASSWORD")
    if not admin_url or not password:
        raise SystemExit("owner-bootstrap requires DATABASE_ADMIN_URL and HONOR_APP_DB_PASSWORD")
    if len(password) < 32:
        raise SystemExit("HONOR_APP_DB_PASSWORD must be at least 32 characters")
    conn=await asyncpg.connect(admin_url, command_timeout=30)
    try:
        await conn.execute("SELECT set_config('honor.bootstrap_password',$1,false)", password)
        await conn.execute("DO $$ BEGIN EXECUTE format('ALTER ROLE honor_app PASSWORD %L', current_setting('honor.bootstrap_password')); END $$;")
        await conn.execute("RESET honor.bootstrap_password")
        flags=await conn.fetchrow("SELECT rolcanlogin,rolbypassrls FROM pg_roles WHERE rolname='honor_app'")
        if flags is None or not flags['rolcanlogin'] or flags['rolbypassrls']:
            raise RuntimeError("honor_app role flags do not match frozen runtime contract")
    finally:
        await conn.close()

if __name__ == '__main__':
    asyncio.run(main())
