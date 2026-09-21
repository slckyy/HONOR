> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Optional-work pause threshold: $43.00. Reserve mode: $51.03. Later builders may not silently change frozen contracts.

# HONOR V1 Authentication / Session Contract

This file is authoritative for V1 owner authentication. It removes all prior conditional wording around cookie auth, JWT validation, Supabase keys, and frontend/server boundaries.

## 1. Frozen V1 owner identity and sign-in
HONOR V1 is a **single-owner Supabase Auth email + password** application.

- Public self-sign-up is disabled at the HONOR UI/API surface.
- The owner is provisioned once from Supabase Dashboard **Authentication → Users → Add user → Send invitation**.
- The Invite email uses HONOR's server-side token-hash confirmation route; the confirmed owner must choose a password before entering `/app`.
- Routine sign-in is email + password using `signInWithPassword`.
- OAuth, phone auth, magic-link login, anonymous users, passkeys, and additional owners are outside V1.
- The owner Supabase Auth UUID is stored server-side as `HONOR_OWNER_USER_ID`. A correctly signed Supabase token for any other `sub` is forbidden.

## 2. Canonical browser → application → database flow

```text
Safari / installed PWA
  │ HTTPS, same HONOR origin
  ▼
Next.js 16 App Router
  ├─ @supabase/ssr browser/server clients
  ├─ Supabase access+refresh session in SSR cookies
  ├─ proxy.ts validates/refreshes protected requests
  ├─ /auth/* owns login/confirm/password/logout
  └─ /api/v1/* same-origin BFF
       │ validates claims; discards browser Authorization
       │ Authorization: Bearer <current Supabase access JWT>
       ▼ private Docker network
     FastAPI
       │ independently validates JWT/JWKS/owner UUID
       ▼
     Supabase Postgres direct IPv6/TLS
       └─ DATABASE_APP_URL → custom honor_app NOBYPASSRLS role
```

The browser **never calls FastAPI directly** in production. Caddy exposes the Next.js application surface. FastAPI is private-Compose-network-only. Browser business-data requests use `/api/v1/*`; browser Supabase usage is limited to Auth/session operations and never directly reads/writes HONOR business tables through the Data API.

## 3. Session cookies, refresh, and PKCE
- Use current `@supabase/ssr`; the user session is cookie-backed for SSR, not a standalone local-storage-only session.
- `@supabase/ssr` initializes PKCE by default. **HONOR V1 has no OAuth or magic-link authorization-code login**, so no active V1 route invents a PKCE callback where one does not exist.
- The canonical V1 Invite and Recovery email paths use Supabase **token hashes** verified server-side with `verifyOtp`; these are not authorization-code exchanges.
- If a future approved auth flow actually returns an authorization code, it must retain PKCE and exchange the code on the same browser/device that initiated the flow. Adding such a flow requires a CHANGE REQUEST because it changes V1 auth capability.
- Next.js `proxy.ts` is the request boundary for protected routes/BFF traffic. It calls `supabase.auth.getClaims()` and propagates any refreshed Supabase `Set-Cookie` values.
- Server code does **not** trust `getSession()` as identity proof. After successful `getClaims()` in the same request context, it may obtain the current access token to forward to FastAPI.
- `@supabase/ssr` owns access/refresh token cookie serialization and refresh-token rotation. HONOR does not repackage refresh tokens into its own cookie.
- Authenticated/session-mutating responses are `Cache-Control: private, no-store`.
- Production auth cookies use HTTPS/`Secure` behavior required by the deployed SSR client. HONOR does not freeze library-private cookie names.
- Refresh tokens are never forwarded to FastAPI and never logged.

## 4. Exact Next.js auth routes
These routes are owned by Next.js and are intentionally outside the FastAPI OpenAPI document.

### `GET /login`
Renders the owner login UI. If the HONOR CSRF cookie is absent/invalid, issue a new `honor_csrf` cookie before rendering. It does not create a Supabase session.

### `POST /auth/login`
Request: `Content-Type: application/json`; body exactly:
```json
{"email":"string","password":"string"}
```
Requires exact same-origin `Origin` and valid `X-HONOR-CSRF`/`honor_csrf` double-submit token.

Behavior:
1. call `signInWithPassword` using `SUPABASE_URL`/publishable key through the SSR client;
2. require returned `user.id == HONOR_OWNER_USER_ID`;
3. if a different valid Supabase user signs in, immediately sign out locally and return the same generic login failure;
4. commit SSR session cookies;
5. rotate `honor_csrf`;
6. return `303 Location: /app`.

Errors: invalid credentials/non-owner return generic `401 AUTH_LOGIN_FAILED`; provider outage returns `503 AUTH_PROVIDER_UNAVAILABLE`. Provider detail is not exposed.

### `POST /auth/recover`
Request: `application/json`; body exactly `{"email":"string"}`. Requires exact same-origin + valid CSRF. Calls `resetPasswordForEmail` for the submitted address and returns generic `202` regardless of whether the address exists. This avoids account enumeration. The Recovery email template points to the token-hash `/auth/confirm` route below.

### Frozen Supabase email templates
In Supabase **Authentication → Email Templates**:
- Invite user link: `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=invite`
- Reset password link: `{{ .SiteURL }}/auth/confirm?token_hash={{ .TokenHash }}&type=recovery`

Supabase **Site URL** is exactly `HONOR_PUBLIC_ORIGIN`. V1 permits only `${HONOR_PUBLIC_ORIGIN}/auth/confirm` as an additional production redirect URL; wildcard production redirects are forbidden.

### `GET /auth/confirm?token_hash=...&type=invite|recovery`
This is the canonical V1 email confirmation/callback.

1. reject a missing token hash or any `type` other than `invite` or `recovery`;
2. call server-side `supabase.auth.verifyOtp({ token_hash, type })` through the SSR client, persisting the resulting session to cookies;
3. require confirmed `user.id == HONOR_OWNER_USER_ID`;
4. on wrong owner, sign out/clear partial session and fail generically;
5. on valid invite, rotate CSRF and return `303 Location: /auth/set-password?mode=invite`;
6. on valid recovery, rotate CSRF and return `303 Location: /auth/set-password?mode=recovery`;
7. expired, consumed, malformed, or wrong-owner token clears partial auth and returns `303 Location: /login?error=AUTH_CONFIRM_INVALID`.

This route accepts **no `next` or external redirect parameter**, eliminating an open-redirect surface.

### `GET /auth/set-password`
Requires a valid Supabase owner session created by Invite/Recovery confirmation. Renders the password form and ensures a valid CSRF cookie. If no valid owner session exists: `303 /login?reason=session_expired`.

### `POST /auth/set-password`
Request: `application/json`; body exactly `{"password":"string"}`. Requires valid owner session, exact same-origin, and valid CSRF. HONOR validates **12–128 Unicode characters** before calling authenticated `supabase.auth.updateUser({ password })`; a stricter Supabase project password policy wins if configured. Success rotates CSRF and returns `303 Location: /app`. Passwords are never logged.

### `POST /auth/logout`
Requires exact same-origin + valid CSRF. Calls `supabase.auth.signOut({ scope: 'local' })`, clears local session state, rotates/clears CSRF as appropriate, and returns `303 Location: /login`. Logout is idempotent; an expired session still lands on `/login`.

## 5. Session expiration and auth-provider failure
- On normal protected traffic, `proxy.ts` verifies/refreshes session state through `getClaims()`.
- Expired/revoked refresh state clears local auth and page navigation becomes `303 /login?reason=session_expired`.
- BFF API requests without a usable owner session return JSON `401 AUTH_REQUIRED`.
- FastAPI malformed/expired/unverifiable access JWT returns `401 AUTH_INVALID`.
- Valid JWT whose `sub` is not the configured owner returns `403 OWNER_FORBIDDEN`.
- Once the JWKS cache expires, inability to verify against Supabase fails closed with `503 AUTH_PROVIDER_UNAVAILABLE`.
- No auth failure falls back to anonymous business access.

## 6. Browser BFF → FastAPI behavior
For every `/api/v1/*` request Next.js:
1. for a mutation, validate exact `Origin` and HONOR CSRF first;
2. validate Supabase session claims;
3. require `sub == HONOR_OWNER_USER_ID`;
4. obtain current access token only after claims validation;
5. discard any browser-supplied `Authorization` header;
6. forward `Authorization: Bearer <Supabase access token>` to internal FastAPI;
7. forward `Idempotency-Key` on endpoints requiring it and forward/generate `X-Request-ID` UUID;
8. mirror the canonical FastAPI status/body while redacting provider internals.

## 7. CSRF / Origin contract
Every browser mutation (`POST`, `PUT`, `PATCH`, `DELETE`) requires **both**:
- normalized `Origin` exactly equals `HONOR_PUBLIC_ORIGIN`; and
- `X-HONOR-CSRF` equals cookie `honor_csrf`.

`honor_csrf` contains at least 32 cryptographically random bytes URL-safe encoded; attributes: `Secure`, `SameSite=Strict`, path `/`, intentionally non-HttpOnly so the app can echo it in the header. It carries no identity/authorization. It is created by `/login` when needed and rotated after successful login, password setup, and logout. `GET`/`HEAD` do not require the header.

Errors: `403 ORIGIN_FORBIDDEN` or `403 CSRF_INVALID`.

FastAPI is private-network-only, so production browser CORS is disabled. Wildcard credentialed CORS is forbidden.

## 8. FastAPI access-JWT validation
Before owner endpoint business logic FastAPI validates:
- JWKS URL: `SUPABASE_JWKS_URL`, canonically `${SUPABASE_URL}/auth/v1/.well-known/jwks.json`;
- issuer: `${SUPABASE_URL}/auth/v1`;
- audience: `authenticated`;
- required claims: `sub`, `iss`, `aud`, `exp`;
- signing key/algorithm must match current JWKS; reject `alg=none` and caller-selected algorithm tricks;
- verifier clock skew ≤ 30 seconds;
- `sub` parses as UUID and exactly equals `HONOR_OWNER_USER_ID`;
- corresponding `owner_profiles` row exists and is active.

JWKS cache TTL is at most 10 minutes. Unknown `kid` triggers exactly one refresh. Cached keys may be used only until TTL expiry; after expiry, verifier outage returns `503 AUTH_PROVIDER_UNAVAILABLE`.

FastAPI never accepts refresh tokens, cookies, publishable keys, Supabase secret/service-role keys, or database passwords as owner authorization.

## 9. Supabase key, RLS, and database boundary
V1 deliberately uses **no Supabase secret key or legacy service-role key at runtime**.

### Browser-permitted public configuration
- `NEXT_PUBLIC_SUPABASE_URL`
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`
- `NEXT_PUBLIC_HONOR_BFF_BASE=/api/v1`

The publishable key is designed for public clients; it is not owner authorization. Business tables are not accessed directly by the browser.

### Server-only configuration
- `SUPABASE_URL`
- `SUPABASE_JWKS_URL`
- `HONOR_OWNER_USER_ID`
- `HONOR_PUBLIC_ORIGIN`
- `HONOR_INTERNAL_API_ORIGIN`
- `DATABASE_APP_URL`
- `DATABASE_ADMIN_URL` only in admin job context
- all OpenAI/R2/Redis/restic/deployment credentials.

### Forbidden browser/runtime credentials
- `SUPABASE_SECRET_KEY`
- legacy `SUPABASE_SERVICE_ROLE_KEY`
- any Postgres URL/password.

`DATABASE_APP_URL` authenticates custom Postgres login `honor_app`, `NOBYPASSRLS`, with least-privilege grants. It is the only DB credential normal FastAPI/worker code receives. `DATABASE_ADMIN_URL` is loaded only into explicit migration, `pg_dump`, and restore commands; it is absent from normal web/API/worker container environments.

Every HONOR application table must have RLS enabled by C01 migrations. `anon` and `authenticated` Data API roles receive no direct business-table DML grants. Database constraints and append-only financial/event/audit protections remain authoritative regardless of API code.

## 10. Representative auth/security acceptance tests
1. Owner invitation token-hash `type=invite` verifies server-side, creates SSR session cookies, and forces `/auth/set-password` before `/app`.
2. Recovery token-hash `type=recovery` verifies server-side and forces password update.
3. Reused/expired/malformed invite or recovery token creates no app access.
4. `/auth/confirm` accepts no external redirect target.
5. Correct owner email/password creates an SSR cookie session and reaches `/app`.
6. Wrong password and non-owner identity return the same generic login failure.
7. Recovery request for owner and unknown email returns the same generic `202` response.
8. Password setup without valid confirmed owner session redirects to login; successful password never appears in logs.
9. Forged auth cookie fails `getClaims()` and never reaches FastAPI.
10. Expired access token refreshes through SSR; invalid refresh state clears session.
11. Browser-supplied `Authorization` is discarded by BFF.
12. FastAPI missing/malformed/expired/bad-signature/bad-issuer/bad-audience JWT returns `401`.
13. Valid Supabase JWT for non-owner `sub` returns `403 OWNER_FORBIDDEN`.
14. Mutation with missing/mismatched `Origin` returns `403 ORIGIN_FORBIDDEN`.
15. Mutation with missing/mismatched CSRF returns `403 CSRF_INVALID`.
16. Cross-site form/request cannot mutate HONOR.
17. Client bundle contains only the three permitted `NEXT_PUBLIC_*` values and no DB/OpenAI/R2/deployment secrets.
18. Supabase secret/service-role key is absent from production runtime env and repository.
19. `honor_app` is `NOBYPASSRLS`, cannot perform schema/admin operations, and Data API roles cannot read/write HONOR business tables.
20. `DATABASE_ADMIN_URL` is absent from web/API/worker runtime and available only to explicit admin jobs.
21. Unknown JWKS `kid` triggers one refresh; outage after cache expiry fails closed.
22. FastAPI is not publicly reachable; only Next.js/Caddy application surface is Internet-exposed.
23. Logout clears local session and repeated logout remains safe.

## 11. Current official basis — reverified 2026-09-20
- Supabase SSR: https://supabase.com/docs/guides/auth/server-side
- Supabase SSR advanced guide / cookie + PKCE behavior: https://supabase.com/docs/guides/auth/server-side/advanced-guide
- Supabase package selection / refresh-token rotation: https://supabase.com/docs/guides/auth/choosing-a-server-package
- Supabase Next.js token-hash confirmation pattern: https://supabase.com/docs/guides/getting-started/tutorials/with-nextjs
- Supabase email templates / invite token hash pattern: https://supabase.com/docs/guides/auth/auth-email-templates
- Supabase users/invites: https://supabase.com/docs/guides/auth/users
- Supabase password update/recovery: https://supabase.com/docs/guides/auth/passwords
- Supabase API keys: https://supabase.com/docs/guides/getting-started/api-keys
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security

`@supabase/ssr` is currently documented as beta/subject to API changes. The security/session semantics above are frozen; a later builder may adapt package-level function syntax only when required by current official guidance, without changing this architecture and with the normal compatibility/change-control record.

## Machine-checkable V1 route set
Canonical Next.js auth routes: `GET /login`; `POST /auth/login`; `POST /auth/recover`; `GET /auth/confirm`; `GET /auth/set-password`; `POST /auth/set-password`; `POST /auth/logout`. `/auth/confirm` accepts only `token_hash` and `type=invite|recovery`. `/auth/callback` does not exist in V1.

`AUTH_ROUTE_SET_V1: GET /login | POST /auth/login | POST /auth/recover | GET /auth/confirm | GET /auth/set-password | POST /auth/set-password | POST /auth/logout`

The machine-readable V1 route set is `HONOR_AUTH_ROUTES.json`.
