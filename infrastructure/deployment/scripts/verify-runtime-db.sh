#!/usr/bin/env bash
set -euo pipefail
ROOT="${DEPLOY_PATH:-/opt/honor}/current"
cd "$ROOT"
docker compose -f infrastructure/docker/compose.production.yml exec -T api python -c "import asyncio,os,asyncpg; exec('async def m():\n c=await asyncpg.connect(os.environ[\"DATABASE_APP_URL\"],command_timeout=10)\n try:\n  assert await c.fetchval(\"SELECT 1\") == 1\n finally:\n  await c.close()\nasyncio.run(m())')"
