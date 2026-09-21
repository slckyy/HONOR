#!/usr/bin/env sh
set -eu
interval="${HONOR_WORKER_MONITOR_INTERVAL_SECONDS:-60}"
case "$interval" in *[!0-9]*|'') echo '{"service":"worker-monitor","severity":"ERROR","event_code":"INVALID_MONITOR_INTERVAL"}'; exit 2;; esac
[ "$interval" -ge 15 ] || interval=15
while true; do
  python -m honor_worker.monitoring || true
  sleep "$interval"
done
