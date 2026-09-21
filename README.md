# HONOR — C01 Foundation

This repository implements the CHECKPOINT-MANAGER-APPROVED C00 Round-12 foundation without adding C02+ product behavior.

## Local start

1. Copy `.env.example` to `.env` and replace **development-only** placeholders. Never commit `.env`.
2. Install Node 22 and Python 3.13. `npm ci --workspaces --include-workspace-root --ignore-scripts` installs the web workspace exactly from the committed resolved lockfile; `python -m venv .venv && . .venv/bin/activate && pip install -r requirements.lock` installs Python dependencies.
3. With Docker available, run `docker compose -f infrastructure/docker/compose.development.yml up --build`.
4. Web: `http://localhost:3000`; public liveness: `http://localhost:3000/healthz` through Caddy when using the full stack.

## Contract discipline

Frozen C00 is retained in `docs/architecture/c00-approved/`. Canonical machine contracts are copied into `packages/contracts/`. Run `python3 scripts/check_contract_drift.py`; CI fails if any canonical copy drifts from the approved C00 package identity recorded in `packages/contracts/C00_INPUT_SHA256.txt`.

## Database

`infrastructure/migrations/0001_c00_database_contract.sql` is a byte-for-byte copy of the approved C00 database contract. `0002_runtime_security.sql` realizes the frozen role/RLS/grant policy. Production migrations use `DATABASE_ADMIN_URL`; API/worker use only `DATABASE_APP_URL`.

## Scope

Only `/healthz` and authenticated `/readyz` are implemented by FastAPI in C01. The frozen `/v1/*` OpenAPI remains authoritative for later checkpoints, but unfinished domain endpoints are deliberately not exposed.

See `CHECKPOINT_C01_REPORT.md` for executed evidence and unverified live-provider items.

Dependency lock regeneration and reproducibility rules are documented in `docs/operations/DEPENDENCY_LOCKS.md`.
