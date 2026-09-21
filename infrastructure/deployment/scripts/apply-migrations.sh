#!/usr/bin/env bash
set -euo pipefail
ROOT="${DEPLOY_PATH:-/opt/honor}/current"
cd "$ROOT"
# The admin URL is injected only into the one-shot migrate service from migration.env.
docker compose -f infrastructure/docker/compose.production.yml --profile admin run --rm --no-deps migrate
