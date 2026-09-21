#!/usr/bin/env bash
set -euo pipefail
BASE="${DEPLOY_PATH:-/opt/honor}"
ROOT="$BASE/current"
STATE="$BASE/state"
ROLE_SENTINEL="$STATE/runtime-role-provisioned"
cd "$ROOT"
COMPOSE=(docker compose -f infrastructure/docker/compose.production.yml)
"${COMPOSE[@]}" pull
"$ROOT/infrastructure/deployment/scripts/apply-migrations.sh"
if [[ ! -f "$ROLE_SENTINEL" ]]; then
  for f in /opt/honor/secrets/api.env /opt/honor/secrets/worker.env /opt/honor/secrets/reconciler.env; do
    [[ -r "$f" ]] || { echo "missing protected runtime DB secret file: $f" >&2; exit 1; }
    grep -q '^DATABASE_APP_URL=' "$f" || { echo "DATABASE_APP_URL missing from protected runtime receiver: $f" >&2; exit 1; }
  done
  [[ -r /opt/honor/secrets/bootstrap.env ]] || { echo "missing owner-bootstrap secret file" >&2; exit 1; }
  "$ROOT/infrastructure/deployment/scripts/provision-runtime-role.sh"
  # Bootstrap credentials are single-use on first deployment. The protected runtime
  # DATABASE_APP_URL receiver files remain; remove the temporary bootstrap file so
  # HONOR_APP_DB_PASSWORD and its admin context are not retained by the deploy host.
  rm -f /opt/honor/secrets/bootstrap.env
  mkdir -p "$STATE"
  : > "$ROLE_SENTINEL"
fi
"${COMPOSE[@]}" up -d --remove-orphans redis api worker reconciler worker-monitor web caddy
curl --fail --silent --show-error --max-time 10 "${HONOR_PUBLIC_ORIGIN:?}/healthz" >/dev/null
# Public liveness is deliberately insufficient; prove runtime DB authentication separately.
"$ROOT/infrastructure/deployment/scripts/verify-runtime-db.sh"
