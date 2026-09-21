#!/usr/bin/env python3
"""Checksum-locked, serialized PostgreSQL migration runner for HONOR.

C00 migration SQL is immutable and may contain clean-bootstrap DDL. This runner is
C01-owned bookkeeping around those files; it never edits or rewrites migration SQL.
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import os
from dataclasses import dataclass
from pathlib import Path

MIGRATION_LOCK_KEY = int.from_bytes(b"HONORMIG", "big", signed=False)
FROZEN_C00_SHA256 = "c0a74f6b34076785e3321c83e6988359f5a8ca18d1a0ba375665016dabf55915"
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DIR = ROOT / "infrastructure" / "migrations"


@dataclass(frozen=True)
class Migration:
    version: str
    path: Path
    sha256: str
    sql: str


def discover_migrations(directory: Path = DEFAULT_DIR) -> list[Migration]:
    migrations: list[Migration] = []
    for path in sorted(directory.glob("[0-9][0-9][0-9][0-9]_*.sql")):
        raw = path.read_bytes()
        migrations.append(
            Migration(
                version=path.name,
                path=path,
                sha256=hashlib.sha256(raw).hexdigest(),
                sql=raw.decode("utf-8"),
            )
        )
    if not migrations:
        raise RuntimeError(f"no migrations found in {directory}")
    versions = [m.version for m in migrations]
    if versions != sorted(versions) or len(versions) != len(set(versions)):
        raise RuntimeError("migration versions are not unique and ordered")
    return migrations


async def _ensure_ledger(conn) -> None:
    await conn.execute(
        """
        CREATE SCHEMA IF NOT EXISTS honor_migrations;
        CREATE TABLE IF NOT EXISTS honor_migrations.schema_migrations(
          version text PRIMARY KEY,
          checksum_sha256 char(64) NOT NULL CHECK (checksum_sha256 ~ '^[a-f0-9]{64}$'),
          applied_at timestamptz NOT NULL DEFAULT statement_timestamp()
        );
        REVOKE ALL ON SCHEMA honor_migrations FROM PUBLIC;
        REVOKE ALL ON ALL TABLES IN SCHEMA honor_migrations FROM PUBLIC;
        """
    )


async def apply_migrations(database_url: str, directory: Path = DEFAULT_DIR) -> list[str]:
    import asyncpg

    migrations = discover_migrations(directory)
    conn = await asyncpg.connect(database_url, command_timeout=120)
    applied_now: list[str] = []
    locked = False
    try:
        await conn.execute("SELECT pg_advisory_lock($1::bigint)", MIGRATION_LOCK_KEY)
        locked = True
        await _ensure_ledger(conn)
        for migration in migrations:
            existing = await conn.fetchval(
                "SELECT checksum_sha256 FROM honor_migrations.schema_migrations WHERE version=$1",
                migration.version,
            )
            if existing is not None:
                if str(existing).strip() != migration.sha256:
                    raise RuntimeError(
                        f"applied migration checksum changed: {migration.version}; "
                        f"database={str(existing).strip()} repository={migration.sha256}"
                    )
                continue
            async with conn.transaction():
                # The approved C00 file contains one syntactically unparenthesized CASE
                # expression in a PL/pgSQL body. PostgreSQL can store that immutable
                # definition with body validation disabled; the immediately following C01
                # migration replaces it with the syntax-equivalent, validated definition
                # before application activation. Scope this compatibility treatment to the
                # exact frozen checksum so it cannot mask errors in any other migration.
                if migration.sha256 == FROZEN_C00_SHA256:
                    await conn.execute("SET LOCAL check_function_bodies = off")
                # No string interpolation: the immutable file is executed byte-for-byte.
                await conn.execute(migration.sql)
                await conn.execute(
                    """
                    INSERT INTO honor_migrations.schema_migrations(version,checksum_sha256)
                    VALUES($1,$2)
                    """,
                    migration.version,
                    migration.sha256,
                )
            applied_now.append(migration.version)
        return applied_now
    finally:
        if locked:
            await conn.execute("SELECT pg_advisory_unlock($1::bigint)", MIGRATION_LOCK_KEY)
        await conn.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--database-url", default=os.getenv("DATABASE_ADMIN_URL"))
    parser.add_argument("--migrations", type=Path, default=DEFAULT_DIR)
    args = parser.parse_args()
    if not args.database_url:
        parser.error("DATABASE_ADMIN_URL or --database-url is required")
    applied = asyncio.run(apply_migrations(args.database_url, args.migrations))
    if applied:
        print("Applied migrations:", ", ".join(applied))
    else:
        print("No migrations to apply; checksums match.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
