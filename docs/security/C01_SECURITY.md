# C01 security implementation

- Runtime DB role `honor_app`: LOGIN, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOINHERIT, NOBYPASSRLS; no table ownership.
- Every HONOR application table has RLS ENABLED + FORCED. `owner_profiles` uses the direct transaction-local predicate; all others use the frozen owner authorization helper.
- Runtime DELETE is revoked globally. Immutable/function-committed histories retain narrower grants.
- Browser receives only approved public Supabase bootstrap values. BFF discards browser Authorization and injects the validated current access token.
- Mutation routes use exact-origin plus double-submit `honor_csrf` protection. `/auth/callback` does not exist.
- FastAPI exposes C01 liveness/readiness only; unfinished C02+ `/v1/*` domain behavior is not faked.
- Polli loads exactly 12 read-only tools; no SQL, shell, arbitrary HTTP, cloud-admin, or mutation capability exists.
- Structured logging redacts secret-like keys and values. CI runs `scripts/secret_scan.py`.
