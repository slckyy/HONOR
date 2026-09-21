#!/usr/bin/env bash
set -euo pipefail
ROOT="${DEPLOY_PATH:-/opt/honor}/current"
cd "$ROOT"
docker compose -f infrastructure/docker/compose.production.yml --profile admin run --rm --no-deps bootstrap-runtime-role
