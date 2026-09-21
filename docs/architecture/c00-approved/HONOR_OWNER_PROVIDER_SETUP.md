> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# Owner Provider Setup — iPhone-first

Never paste secret values into ChatGPT, GitHub issues, screenshots, or checkpoint reports. Record only non-secret evidence such as resource name, plan, region, bucket name, project ID, and a screenshot with secrets hidden.

## Actions required now
### 1. GitHub — create the canonical private repository
1. In Safari, sign in to GitHub.
2. Open the `+` menu → **New repository**.
3. Repository name: `HONOR`.
4. Visibility: **Private**.
5. Do not add secrets. README/license can be added by the builder.
6. In account billing/budgets, keep GitHub Actions paid overage blocked/at zero if the UI permits a stop-usage budget.
7. Enable 2FA on the GitHub account if not already enabled.

Expected non-secret evidence: repository name `HONOR`, private visibility, owner account/organization name. Billing required now: **No** for GitHub Free.

### 2. Supabase — create one free project
1. Sign in to Supabase in Safari.
2. Create a new organization/project named `HONOR`.
3. Choose a US region reasonably close to the deployment region.
4. Stay on **Free**.
5. Generate/store the database password in a password manager; do not paste it into chat.
6. In project settings, note the project URL/reference as non-secret evidence.

Secrets/config later:
- `NEXT_PUBLIC_SUPABASE_URL` — browser-permitted project URL.
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` — browser-permitted publishable key; not owner authorization.
- `SUPABASE_URL` — server-side project URL/config.
- `SUPABASE_JWKS_URL` — server-side JWKS URL/config.
- `DATABASE_APP_URL` — secret direct-IPv6 Postgres URL for custom `honor_app` runtime role.
- `DATABASE_ADMIN_URL` — secret direct-IPv6 Postgres URL for migrations/pg_dump/restore only.

V1 does **not** require or permit a Supabase secret/service-role key in runtime. Do not create/store one for HONOR unless an approved CHANGE REQUEST later requires it.

Billing required now: **No**. Do not upgrade to Pro in Month 1 without an approved change request.

### 3. Better Stack — free monitoring workspace
1. Create/sign in to Better Stack.
2. Use the free personal-project tier.
3. Create a workspace/team named `HONOR`.
4. Do not create paid responders/add-ons.

Later non-secret evidence: monitor names and status. Secret later: heartbeat URLs/tokens stored server-side. Billing required now: **No**.

## Accounts to create now, paid resource deliberately deferred
### DigitalOcean
Create/sign in to a DigitalOcean account and create a project named `HONOR`, but **do not create the Droplet until the deployment checkpoint instructs you to do so**. This preserves the $56.03 budget while builders work.

When authorized later, exact frozen resource is:
- Basic Droplet → Regular CPU.
- 4 GiB RAM / 2 vCPU / 80 GiB SSD plan listed at $24/month at C00 research time.
- Ubuntu 24.04 LTS or 26.04 LTS only if all pinned dependencies are validated; default deployment target: Ubuntu 24.04 LTS for ecosystem maturity.
- Authentication: SSH key, not password-only.
- Backups add-on: **do not buy**; HONOR uses its own encrypted R2 backup flow.

Config later: `HONOR_PUBLIC_ORIGIN` plus GitHub **repository** secret `DEPLOY_SSH_PRIVATE_KEY` and repository variables `DEPLOY_HOST`, `DEPLOY_SSH_KNOWN_HOSTS`, `DEPLOY_USER`, and `DEPLOY_PATH`—never chat.

### Cloudflare R2
Create/sign in to Cloudflare now if convenient. Creating the R2 subscription may require a payment method, so the actual R2 bucket can be deferred until storage integration.

When authorized later create:
- bucket `honor-media`
- bucket `honor-backups`
- Standard storage class.
- private access; no public bucket.

Server secrets later:
- `R2_ACCOUNT_ID`
- `R2_MEDIA_ACCESS_KEY_ID`
- `R2_MEDIA_SECRET_ACCESS_KEY`
- `R2_BUCKET_MEDIA`
- `R2_BUCKET_BACKUPS`
- `R2_ENDPOINT`

Store access keys only in server/GitHub deployment secrets. Billing: enable only when storage checkpoint is ready; monitor usage.

### OpenAI API
Use the API platform, not the ChatGPT Plus subscription, for HONOR runtime calls.

When AI integration checkpoint begins:
1. Create a project named `HONOR`.
2. Add payment details.
3. Buy **$10 initial prepaid credits** (current minimum is $5; $10 gives practical headroom without committing the full allocation).
4. Turn **auto-reload OFF**.
5. Set project spend controls to no more than the frozen **$15 Month-1 OpenAI allocation** and enable alerts below the limit. HONOR's internal governor remains authoritative because provider reporting may lag.
6. Create a restricted project/service key for the server.
7. Store `OPENAI_API_KEY` in the server/GitHub secret store only.

Do not expose the key to the PWA. Polli Live sessions are created by FastAPI using server-side credentials.

Expected non-secret evidence: project name `HONOR`, spend limit/alert settings, credit balance with no key visible.

## Deliberately deferred purchases
- Domain name: choose/buy at deployment only after exact cost is known. If an existing owner-controlled domain is available, prefer using it.
- Runpod: no account funding and no endpoint at launch.
- Supabase Pro: no.
- Managed Redis: no.
- Paid monitoring: no.

## Safe verification method
A later builder/checkpoint may ask for screenshots or copied non-secret IDs. Before sharing:
- hide API keys, access keys, database passwords, JWTs, recovery codes, SSH private keys, billing card details, signed URLs, webhook secrets, and full `.env` files;
- if a secret was accidentally exposed, treat it as compromised and rotate it before continuing.

## Provider fallback rules
- DigitalOcean unavailable: submit CHANGE REQUEST for an equivalent Linux VPS with >=2 vCPU, >=4 GiB RAM, predictable monthly price that preserves $56.03 cap.
- Supabase unavailable: no silent DB replacement; CHANGE REQUEST required because DB/Auth contracts are frozen.
- R2 unavailable: S3-compatible object store may substitute only via approved CHANGE REQUEST; object-key contract remains.
- Better Stack unavailable: a free uptime/heartbeat alternative may be proposed; health endpoint and heartbeat contract remain.
- OpenAI outage: text/voice/transcription jobs enter retrying/blocked states; no fake success. Local media-only work may continue when it does not require missing AI output.

## C00 Round-2 auth-route freeze
Canonical V1 auth routes are exactly `GET /login`, `POST /auth/login`, `POST /auth/recover`, `GET /auth/confirm?token_hash=...&type=invite|recovery`, `GET /auth/set-password`, `POST /auth/set-password`, and `POST /auth/logout`. No `/auth/callback` or authorization-code callback exists in V1. Supabase Invite and Recovery templates point to `/auth/confirm` and are verified server-side with `verifyOtp`.

## Redis credential procedure (iPhone-first, no secret pasted into chat)
Redis has no external account. During deployment, the bootstrap command on the Droplet generates `REDIS_PASSWORD` locally with a cryptographically secure generator (minimum 32 random bytes) and writes it directly to the root-owned HONOR server secret file with mode `0600`; the value is not displayed in checkpoint evidence. Redis is configured with `requirepass` and no published host port. Safe verification is a redacted `PING` success from the API/worker container plus a deliberate wrong-password failure; evidence shows only PASS/FAIL and secret variable name.

Public monitor URL is `${HONOR_PUBLIC_ORIGIN}/healthz`. Do not point Better Stack or DigitalOcean at `/readyz`; owner readiness is `/api/readyz` after login.

`AUTH_ROUTE_SET_V1: GET /login | POST /auth/login | POST /auth/recover | GET /auth/confirm | GET /auth/set-password | POST /auth/set-password | POST /auth/logout`

The machine-readable V1 route set is `HONOR_AUTH_ROUTES.json`.

### Public health routing evidence
Better Stack probes `${HONOR_PUBLIC_ORIGIN}${HONOR_PUBLIC_HEALTH_PATH}` = public `/healthz`. DigitalOcean Monitoring itself uses the Droplet agent and does not require an HTTP readiness URL; if a DigitalOcean HTTP uptime probe is configured, its only permitted target is the same public `/healthz`. `/api/readyz` and internal `/readyz` are owner-authenticated/private and must never be configured as public monitor targets.

### Canonical Redis V1 startup/auth contract
Redis is reachable only on the internal Docker Compose network and publishes no host port. The container command/config contract is equivalent to `redis-server --protected-mode yes --requirepass "$REDIS_PASSWORD" --appendonly yes`; the secret is supplied from the root-owned server secret environment at container start, never committed and never printed. API/worker construct `redis://:${REDIS_PASSWORD}@${REDIS_HOST}:${REDIS_PORT}/<db>` server-side. Celery broker DB is `1`; result backend DB is `2`; HONOR cache/lease DB is `0`. A missing or wrong password must fail closed.


## Canonical provider/setup matrix
The matrix below is authoritative for C00. “No owner resource” means the service is installed/configured on the selected Droplet rather than purchased separately.

| Provider/service | Official source | Purpose / frozen starting tier | Month-1 range | Exact resource / iPhone action | Billing now? / do not buy | ENV/config | Secret storage + safe verification | Outage fallback |
|---|---|---|---:|---|---|---|---|---|
| GitHub | https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository ; https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions | One canonical **private** repo; GitHub Free | $0 | Safari → GitHub → `+` → New repository → `HONOR` → Private. Repository Actions secrets/variables only. | No billing now; do not buy Team/Copilot for infrastructure. | `DEPLOY_SSH_PRIVATE_KEY` secret; `DEPLOY_HOST`, `DEPLOY_SSH_KNOWN_HOSTS`, `DEPLOY_USER`, `DEPLOY_PATH` variables | GitHub repository secret/variables; verify secret **name** exists and repo is Private, never reveal value. | If GitHub unavailable, deployment is BLOCKED; provider change requires CHANGE REQUEST. |
| DigitalOcean Droplet | https://www.digitalocean.com/pricing/droplets | Always-on Linux app/API/worker/media host; Basic Regular 4 GiB / 2 vCPU / 80 GiB | $24 fixed planned | Account/project now; create exact Droplet only at deployment checkpoint; enable IPv6 at creation. | Billing deferred until deployment; do not buy managed DB/backups. | `DEPLOY_HOST`, `HONOR_PUBLIC_ORIGIN` | DO account + GitHub repo variables; verify plan/region/IPv6 and redacted health only. | Equivalent VPS only by approved CHANGE REQUEST preserving cap. |
| DigitalOcean Monitoring + Cloud Firewall | https://docs.digitalocean.com/products/monitoring/ ; https://docs.digitalocean.com/products/networking/firewalls/ | Host metrics/alerts + network allowlist; included/free features for selected Droplet at C00 research | $0 | On Droplet: enable Monitoring agent; create Cloud Firewall allowing 80/443 public and SSH only from controlled admin path as deployment contract specifies. | No separate paid add-on; do not buy paid observability solely for launch. | no app secret; firewall/monitor config in provider | DO control plane; verify agent healthy/firewall rules without showing credentials. | App continues with degraded monitoring; security-sensitive firewall loss is BLOCKED until restored. |
| Supabase | https://supabase.com/docs/guides/auth/server-side ; https://supabase.com/docs/guides/database/connecting-to-postgres | Auth + Postgres; Free | $0 | Safari → project → **Connect**: record Project URL/publishable key; select **Direct connection** `db.<ref>.supabase.co:5432` for Droplet IPv6. Store DB password in password manager. | No billing; no Pro/IPv4 add-on. | `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_URL`, `SUPABASE_JWKS_URL`, `DATABASE_APP_URL`, `DATABASE_ADMIN_URL` | Publishable values may be browser-visible; DB URLs/passwords only root-owned server secret/admin context. Verify Droplet `curl -6` and TLS DB connection without printing URL/password. | No silent DB/Auth replacement; CHANGE REQUEST required. |
| Cloudflare R2 | https://developers.cloudflare.com/r2/pricing/ | Private media + encrypted backups; Standard | $0 expected within free tier | Cloudflare → R2 → create private media and backup buckets when storage checkpoint begins. | Billing/payment method may be required then; do not buy extra storage plan. | `R2_ACCOUNT_ID`, `R2_ENDPOINT`, `R2_BUCKET_MEDIA`, `R2_BUCKET_BACKUPS`, `R2_MEDIA_ACCESS_KEY_ID`, `R2_MEDIA_SECRET_ACCESS_KEY`, `R2_BACKUP_ACCESS_KEY_ID`, `R2_BACKUP_SECRET_ACCESS_KEY`, `RESTIC_PASSWORD` | Root-owned server secret/GitHub deploy secret path; verify PUT/GET/delete test object with redacted output. | S3-compatible replacement only by CHANGE REQUEST. |
| OpenAI API | https://platform.openai.com/docs ; https://openai.com/api/pricing/ | Transcription/Polli voice/reasoning; project prepaid controls | $5–$15 allocation, internal max $15 | API platform → project `HONOR`; fund only when AI checkpoint begins; auto-reload OFF. | Billing deferred; no subscription beyond needed prepaid API credits. | `OPENAI_API_KEY`, `OPENAI_PROJECT_ID`, frozen model config variables | Server/GitHub deployment secret only; verify redacted model-list/minimal request and cost ledger record. | AI jobs retry/block; no fake success; local media-only work may continue. |
| Better Stack | https://betterstack.com/uptime | Public liveness + heartbeats; Free | $0 | Create workspace/monitors when deployment begins; HTTP target only public `/healthz`. | No paid responders/add-ons. | optional `BETTERSTACK_API_TOKEN`, heartbeat URLs | Server secret file; verify public liveness and heartbeat status with no token shown. | Monitoring degraded; app remains functional; free replacement may be proposed without changing health contract. |
| Redis | https://redis.io/docs/latest/operate/oss_and_stack/management/security/ | Queue/cache/leases; self-hosted Redis on Droplet | $0 incremental | **No owner account/resource required.** Deployment creates internal Compose service with no host port and `requirepass`. | No managed Redis. | `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`, `REDIS_CACHE_DB` | `REDIS_PASSWORD` only in root-owned server secret file; verify authenticated PING succeeds and wrong password fails. | Durable truth remains Postgres; queue dispatch pauses until Redis returns. |
| Celery | https://docs.celeryq.dev/ | Durable worker dispatch over Redis | $0 incremental | **No owner account/resource required.** Installed in worker image. | No paid queue service. | `CELERY_BROKER_DB`, `CELERY_RESULT_DB` plus server-constructed authenticated URLs | Uses same Redis secret; verify test job + restart persistence. | Jobs remain durable in Postgres/reconciler and redispatch after recovery. |
| Docker | https://docs.docker.com/engine/install/ | Container runtime/Compose | $0 | **No owner account/resource required.** Installed on Droplet from official packages. | Do not buy Docker subscription for server runtime. | deployment config only | No product secret required; verify pinned images/health. | Host runtime failure is BLOCKED until repaired; provider switch needs CHANGE REQUEST if architecture changes. |
| Caddy | https://caddyserver.com/docs/ | TLS/reverse proxy/public `/healthz` | $0 | **No owner account/resource required.** Installed/containerized on Droplet. | No paid Caddy service. | `HONOR_PUBLIC_ORIGIN`, health route constants | No app secret beyond TLS material managed by Caddy; verify HTTPS + route behavior. | Equivalent reverse proxy requires CHANGE REQUEST; no silent switch. |
| Runpod | https://docs.runpod.io/serverless/overview | Optional burst GPU abstraction | $0 launch | **Deferred: no owner account/endpoint required.** | Do not fund/create endpoint at launch. | `GPU_PROVIDER=disabled`; blank `RUNPOD_API_KEY`, `RUNPOD_ENDPOINT_ID` | None while disabled. | CPU path remains canonical; enabling any GPU spend requires governor capacity and later approved setup. |

### Supabase connection strings on iPhone — safe procedure
1. Safari → Supabase project → **Connect**.
2. For Month 1 choose **Direct connection**, not IPv4 add-on and not a pooler for the canonical Droplet path. Confirm host form `db.<project-ref>.supabase.co`, port `5432`, TLS required.
3. Store the project database password in the owner password manager. Do **not** paste a full connection string/password into chat or screenshots.
4. `DATABASE_ADMIN_URL` uses the direct host with the admin/postgres login only in migration/backup/restore context.
5. After C01 creates the custom `honor_app` role/password, deployment constructs `DATABASE_APP_URL` with the same direct IPv6 host/port. The runtime role/password is stored only in the root-owned server secret file.
6. Safe evidence is project ref, direct-host pattern, port, “IPv6 enabled / connection PASS,” and redacted role name—never password or URL containing it.

## GitHub Actions deployment SSH credential — iPhone-first secure procedure
This procedure uses **repository** secrets/variables on GitHub Free; it never asks the owner to paste a private key into ChatGPT.

1. At the deployment checkpoint, open the DigitalOcean web Console for the HONOR Droplet in Safari and create/confirm Linux user `honor` with least-privilege deploy permissions.
2. In that console, generate a dedicated ED25519 pair solely for GitHub Actions. Add the **public** key to `/home/honor/.ssh/authorized_keys` with correct ownership/permissions. The key is not the owner’s personal SSH key.
3. Display the new private key only for the direct transfer step. In a separate Safari tab open GitHub repo → **Settings → Secrets and variables → Actions → Secrets → New repository secret**. Create `DEPLOY_SSH_PRIVATE_KEY` and paste the private key there. Do not screenshot it, save it in Notes, or send it to chat. After GitHub confirms the secret is stored, delete the temporary private-key file from the Droplet console session.
4. From the Droplet console, derive the SSH host-key line from the server’s existing **public host key** and public IP/hostname. Add that non-secret line as repository variable `DEPLOY_SSH_KNOWN_HOSTS`; add `DEPLOY_HOST`, `DEPLOY_USER=honor`, and `DEPLOY_PATH=/opt/honor` as repository variables.
5. GitHub Actions must write `DEPLOY_SSH_KNOWN_HOSTS` into `~/.ssh/known_hosts` and use strict host-key checking. It must never run `StrictHostKeyChecking=no` and must never fetch/accept an unknown host key implicitly.
6. Safe checkpoint evidence: secret **name exists**, variable names/values that are non-secret, host-key fingerprint, and a successful redacted SSH `whoami`/deploy check. Never reveal the private key.
7. Rotation: generate a new dedicated pair, append new public key, replace the repository secret, test, then remove the old public key. Suspected exposure means immediate rotation.


# Single-owner Supabase bootstrap — exact iPhone-first sequence
Bootstrap timing invariant: create the Supabase Free project during provider setup; configure production Auth URL/templates, send the owner invitation, capture `HONOR_OWNER_USER_ID`, and create/verify the matching `owner_profiles` row only after the public HTTPS `HONOR_PUBLIC_ORIGIN` exists and the C01 migrations have created the frozen table/policies. Until then those steps are **DEFERRED TO CHECKPOINT X: DEPLOYMENT/BOOTSTRAP**.
Official basis: Supabase Dashboard invitation flow, SSR cookie guidance, token-hash email templates, and URL Configuration. Never paste a password, JWT, DB URL, secret/service-role key, R2 key, or session into ChatGPT.

## Phase A — C00/provider account (may happen before migrations)
1. On iPhone Safari, sign in to Supabase Dashboard and create the frozen Free project if it does not already exist. Record only non-secret project name/reference in owner notes.
2. Do **not** create the HONOR Auth owner yet if the deployed `HONOR_PUBLIC_ORIGIN` and C01 schema are not ready. The `owner_profiles` table/policies must exist before final access verification.
3. Do not create or expose a Supabase secret/service-role key for HONOR runtime. Browser receives only project URL + publishable key.

## Phase B — DEFERRED TO CHECKPOINT X: DEPLOYMENT/BOOTSTRAP
`X` means the Checkpoint Manager-assigned deployment checkpoint; do not perform these steps during C00 or C01 until the public HTTPS origin and migrations exist.

1. Confirm the deployed HTTPS origin that will be stored as `HONOR_PUBLIC_ORIGIN` (example shape `https://honor.example.com`; no example value is a real resource).
2. Supabase Dashboard -> Authentication -> URL Configuration:
   - set **Site URL** to exactly `HONOR_PUBLIC_ORIGIN`;
   - add the exact production redirect URL `HONOR_PUBLIC_ORIGIN/auth/confirm`;
   - do not add `/auth/callback`; do not add broad production wildcards.
3. Authentication -> Email Templates -> **Invite user**. Make the action link exactly:
   `<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=invite">Accept HONOR invite</a>`
4. Authentication -> Email Templates -> **Reset password**. Make the action link exactly:
   `<a href="{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=recovery">Reset HONOR password</a>`
5. Authentication -> Users -> **Add user** -> **Send invitation**. Enter only the owner's own email in Supabase; do not paste it into ChatGPT. Open the invite on the iPhone, follow `/auth/confirm`, then set the password on `/auth/set-password`.
6. Back in Authentication -> Users, open the owner row and copy the user's UUID. The UUID is an identifier, not a password/JWT. Store it as `HONOR_OWNER_USER_ID` in the root-owned server runtime env and, if the deployment workflow needs it, the GitHub **repository variable** of the same name. Never store auth tokens.
7. After C01 migrations exist, run the frozen one-time admin/bootstrap operation using `DATABASE_ADMIN_URL` on the Droplet (not the runtime DB connection):
```sql
INSERT INTO owner_profiles (user_id, display_name, timezone, active)
VALUES (:HONOR_OWNER_USER_ID, 'Owner', 'America/Chicago', true)
ON CONFLICT (user_id) DO UPDATE
SET active = true, timezone = EXCLUDED.timezone, updated_at = now();
```
The bootstrap runner binds `:HONOR_OWNER_USER_ID`; the owner is not asked to type SQL on iPhone. Verify exactly one active row matches the Auth UUID.
8. Login acceptance: owner login succeeds; expired invite/recovery token shows a safe re-request message; logout clears the session; refresh-token rotation is cookie-managed by `@supabase/ssr`.
9. Non-owner denial test (deployment acceptance): using a separate test email controlled by the owner, temporarily send a second Dashboard invitation. In a private browser session, authenticate that test user and call a normal HONOR page/BFF route. Expected result: `403 OWNER_FORBIDDEN`, no HONOR business data, and no mutation. Delete/disable the temporary test user after evidence is captured. No test password/session/JWT is pasted into ChatGPT or committed.

# Cloudflare R2 credentials — exact V1 mapping
At the storage/deployment checkpoint, create **two** R2 API credentials; do not reuse one. Cloudflare Dashboard -> Storage & databases -> R2 -> Overview -> Manage API Tokens.

1. **HONOR runtime media token**: Object Read & Write, **specific bucket only** = `honor-media`. Save its Access Key ID as `R2_MEDIA_ACCESS_KEY_ID` and Secret Access Key as `R2_MEDIA_SECRET_ACCESS_KEY` in the root-owned server secret file. Inject only into API/worker/media.
2. **HONOR backup token**: Object Read & Write, **specific bucket only** = `honor-backups`. Save as `R2_BACKUP_ACCESS_KEY_ID` / `R2_BACKUP_SECRET_ACCESS_KEY`. Inject only into backup/restic. Docker Compose maps these two values inside that container to `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, because Restic's S3 backend expects AWS-compatible variable names. They are aliases, not a third credential.
3. Next.js/browser gets no R2 secret. Presigned media URLs are issued server-side with short TTL.
4. Safe verification: with redacted logs, runtime credential can PUT/GET/list/delete a disposable object in `honor-media` and must fail against `honor-backups`; backup credential can initialize/list/check the Restic repository in `honor-backups` and must fail against `honor-media`. Never print key values.
5. Rotation: create replacement token with same one-bucket scope -> update only the matching secret pair -> restart only its consumers -> repeat safe verification -> revoke old token.


## Credential/container injection matrix
| Credential/config | Scope | Receivers | Forbidden receivers |
|---|---|---|---|
| `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | public Auth bootstrap | browser + Next.js | n/a; publishable by design |
| `DATABASE_APP_URL` | honor_app NOBYPASSRLS DB | FastAPI + worker | browser/Next.js client bundle |
| `DATABASE_ADMIN_URL` | migrations/bootstrap/backup admin | migration/backup/admin job only | browser, Next.js runtime, API/worker normal runtime |
| `R2_MEDIA_ACCESS_KEY_ID`, `R2_MEDIA_SECRET_ACCESS_KEY` | R2 Object R/W: honor-media only | API/worker/media | browser/Next.js/backup |
| `R2_BACKUP_ACCESS_KEY_ID`, `R2_BACKUP_SECRET_ACCESS_KEY` | R2 Object R/W: honor-backups only | backup/restic | browser/Next.js/API/worker/media |
| `REDIS_PASSWORD` | internal Redis | API/worker/Celery | browser/Next.js client bundle |
| `OPENAI_API_KEY` | OpenAI server API | API/Polli/worker as needed | browser |
| `DEPLOY_SSH_PRIVATE_KEY` | GitHub Actions -> Droplet deploy | GitHub repository secret only | server repo/browser/chat |

Credential mapping machine authority: `HONOR_SECRET_ENV_REGISTRY.json`.

Credential mapping machine authority: `HONOR_SECRET_ENV_REGISTRY.json`.

Credential mapping machine authority: `HONOR_SECRET_ENV_REGISTRY.json`.

Monitoring credential mapping: `BETTERSTACK_API_TOKEN` is optional setup-only; `BETTERSTACK_BACKUP_HEARTBEAT_URL` is backup-only; `BETTERSTACK_WORKER_HEARTBEAT_URL` is worker-only. Store all as server-side secrets and verify only redacted heartbeat PASS/FAIL status.

## Round-11 owner-action terminal decisions

Owner-action review is not a free-form mutable note. New actions are created `OPEN` with database-authored request/creation time. Resolution is a single guarded `OPEN -> RESOLVED` transition with DB-authored `resolved_at`, canonical resolution JSON and immutable `resolution_sha256`; optional cancellation is `OPEN -> CANCELLED` with DB-authored `cancelled_at` and canonical cancellation context. RESOLVED/CANCELLED actions cannot reopen or be rewritten. Restriction-compliance owner review is limited to the already-approved owner-resolvable codes and exact campaign/rule/candidate/target/content context.
