# Deployment skeleton

Production topology is Internet → Caddy → Next.js. Caddy may proxy only `/healthz` directly to FastAPI. FastAPI `/readyz` is private and owner-facing readiness is Next.js `/api/readyz`. FastAPI `/v1/*` is never routed publicly. Redis is internal-only. Supabase Postgres is external and runtime uses `honor_app` through `DATABASE_APP_URL`.

## Release web image
The three approved `NEXT_PUBLIC_*` values are non-secret image-build inputs and are frozen by `next build`. Use `infrastructure/deployment/env/web-build.env.example`; editing runtime `web.env` does not change browser values. Never pass server credentials as web build args.

## First deployment ordering
1. Install protected migration/bootstrap/runtime receiver files.
2. Pull release images.
3. Run checksum-locked migrations through the one-shot `migrate` service.
4. If `$DEPLOY_PATH/state/runtime-role-provisioned` does not exist, verify protected `DATABASE_APP_URL` receiver files exist, then run one-shot `bootstrap-runtime-role`. `/opt/honor/secrets/bootstrap.env` contains only `DATABASE_ADMIN_URL` and implementation-only `HONOR_APP_DB_PASSWORD`. The latter is the password embedded in protected `DATABASE_APP_URL`; it is never logged, echoed, or injected into runtime services. After successful provisioning, `deploy.sh` deletes the single-use `bootstrap.env`; recreate it only for an explicit owner-bootstrap/password-rotation operation.
5. Activate Redis/API/worker/reconciler/worker-monitor/web/Caddy only after bootstrap succeeds.
6. Verify public `/healthz`.
7. Separately verify runtime DB authentication from the API container. Public health is not DB/readiness proof.
8. When live Supabase owner auth exists, verify authenticated `/api/readyz`; C01 does not require creating that provider solely for source repair.

Normal deployments reuse the sentinel and do not re-provision the role. Explicit password rotation is owner-bootstrap context and must update protected runtime URLs coherently. `DATABASE_ADMIN_URL` remains confined to migration/backup/owner-bootstrap.

## Worker monitoring
The `worker-monitor` service uses the existing worker image and no paid service. It sends the optional Better Stack worker heartbeat only when a Celery worker responds and the reconciler has refreshed its short-lived Redis liveness marker. If the URL is unset, monitoring delivery is disabled cleanly. Health or network failure emits only a safe event code and cannot terminate domain work. Better Stack remains NOT VERIFIED until owner setup eventually exists.

DigitalOcean, domain, Supabase, R2, OpenAI, Better Stack, and SSH resources are not created by C01.
