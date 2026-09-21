from __future__ import annotations

import asyncio
import os
import subprocess
from pathlib import Path

import pytest

from scripts.migrate import apply_migrations

ROOT = Path(__file__).resolve().parents[2]
ADMIN_URL = os.getenv("TEST_DATABASE_ADMIN_URL")
APP_URL = os.getenv("TEST_DATABASE_APP_URL")
OWNER = "00000000-0000-0000-0000-000000000001"


def _required(name: str, value: str | None) -> None:
    if os.getenv("GITHUB_ACTIONS", "").lower() == "true" and not value:
        pytest.fail(f"{name} is mandatory in CI; infrastructure tests may not silently skip")


def admin_psql(sql: str) -> str:
    _required("TEST_DATABASE_ADMIN_URL", ADMIN_URL)
    return subprocess.check_output(
        ["psql", ADMIN_URL, "-v", "ON_ERROR_STOP=1", "-Atc", sql], text=True
    ).strip()


def app_psql(sql: str, *, check: bool = True) -> subprocess.CompletedProcess[str] | str:
    _required("TEST_DATABASE_APP_URL", APP_URL)
    proc = subprocess.run(
        ["psql", APP_URL, "-v", "ON_ERROR_STOP=1", "-Atc", sql],
        text=True,
        capture_output=True,
    )
    if check:
        if proc.returncode:
            raise RuntimeError(proc.stderr + proc.stdout)
        return proc.stdout.strip()
    return proc


@pytest.fixture(scope="session")
def migrated_database():
    _required("TEST_DATABASE_ADMIN_URL", ADMIN_URL)
    _required("TEST_DATABASE_APP_URL", APP_URL)
    if not ADMIN_URL or not APP_URL:
        pytest.skip("Postgres integration URLs not configured")
    reset = """
    DROP EXTENSION IF EXISTS pgcrypto CASCADE;
    DROP SCHEMA IF EXISTS honor_migrations CASCADE;
    DROP SCHEMA IF EXISTS auth CASCADE;
    DROP SCHEMA public CASCADE;
    CREATE SCHEMA public;
    DROP ROLE IF EXISTS honor_app;
    """
    subprocess.run(["psql", ADMIN_URL, "-v", "ON_ERROR_STOP=1", "-c", reset], check=True)
    subprocess.run(
        ["psql", ADMIN_URL, "-v", "ON_ERROR_STOP=1", "-f", str(ROOT / "tests/integration/bootstrap_auth_stub.sql")],
        check=True,
    )
    applied = asyncio.run(apply_migrations(ADMIN_URL))
    admin_psql(
        f"ALTER ROLE honor_app PASSWORD 'dev-only-honor-app';"
        f"INSERT INTO auth.users(id) VALUES ('{OWNER}') ON CONFLICT DO NOTHING;"
        f"INSERT INTO owner_profiles(user_id,display_name,timezone,active) VALUES "
        f"('{OWNER}','C01 Integration Owner','America/Chicago',true) "
        "ON CONFLICT(user_id) DO UPDATE SET active=true;"
    )
    return applied
