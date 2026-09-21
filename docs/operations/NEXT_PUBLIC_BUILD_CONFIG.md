# Next.js public release configuration

HONOR follows the Next.js 16 environment model: `NEXT_PUBLIC_*` references are inlined during `next build` and are frozen in the browser bundle. Runtime `/opt/honor/config/web.env` therefore cannot replace these client values after an image is built.

Every release web image is built with exactly three non-secret Docker build args: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, and `NEXT_PUBLIC_HONOR_BFF_BASE` (normally `/api/v1`). The template is `infrastructure/deployment/env/web-build.env.example`. C01 CI uses obvious non-live fixtures. When live Supabase setup eventually exists, the release image is rebuilt with its approved public values.

No `DATABASE_*`, `REDIS_*`, `R2_*`, `OPENAI_*`, `RESTIC_*`, Better Stack secret URL, or deployment credential is a web-image build argument. Changing a runtime `web.env` cannot rewrite already-built client assets.

Official guidance verified 2026-09-21: Next.js “Environment Variables” → “Bundling Environment Variables for the Browser”.
