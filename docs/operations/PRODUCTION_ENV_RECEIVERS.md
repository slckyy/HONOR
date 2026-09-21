# Production environment receivers

No common runtime secret file exists.

| File | Receiver | Contents |
|---|---|---|
| `/opt/honor/secrets/redis.env` | Redis | `REDIS_PASSWORD` |
| `/opt/honor/secrets/api.env` | API | `DATABASE_APP_URL`, Redis, R2 media, OpenAI runtime secrets |
| `/opt/honor/secrets/worker.env` | worker/Celery | `DATABASE_APP_URL`, Redis, R2 media, OpenAI runtime secrets |
| `/opt/honor/secrets/reconciler.env` | reconciler | `DATABASE_APP_URL`, `REDIS_PASSWORD` |
| `/opt/honor/secrets/worker-monitoring.env` | worker liveness reporter | `REDIS_PASSWORD`, `BETTERSTACK_WORKER_HEARTBEAT_URL` |
| `/opt/honor/secrets/migration.env` | migration | `DATABASE_ADMIN_URL` |
| `/opt/honor/secrets/bootstrap.env` | owner-bootstrap | `DATABASE_ADMIN_URL`, implementation-only `HONOR_APP_DB_PASSWORD` |
| `/opt/honor/secrets/backup.env` | backup/restic | admin DB, R2 backup, restic, backup heartbeat secrets |
| `/opt/honor/config/web.env` | Next.js runtime | non-secret runtime metadata only; no `NEXT_PUBLIC_*` replacement |
| `/opt/honor/config/caddy.env` | Caddy | non-secret `HONOR_PUBLIC_HOST` only |

`worker-monitor` is a narrow process within the frozen worker receiver class. `HONOR_APP_DB_PASSWORD` is not a new C00 runtime credential: it exists only in explicit owner-bootstrap context to set the password represented inside protected `DATABASE_APP_URL` receiver files. It is never injected into ordinary runtime services, and the single-use `bootstrap.env` is deleted after successful first-deploy role provisioning. `BETTERSTACK_API_TOKEN` remains setup-only, `RUNPOD_API_KEY` remains unset, and deployment SSH material remains GitHub Actions-only.

The three `NEXT_PUBLIC_*` values are public build inputs documented in `NEXT_PUBLIC_BUILD_CONFIG.md`. Restricted no-domain staging uses `HONOR_PUBLIC_HOST=:80`; stable HTTPS uses the approved hostname without source edits.
