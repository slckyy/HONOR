> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.
# Official Research Sources

Research completed/checked on **2026-09-20**. First-party official sources were preferred. Pricing and product limits may change; re-verify before purchase/deployment.

- **OpenAI GPT-5.6 Sol model/pricing:** https://developers.openai.com/api/docs/models/gpt-5.6-sol
- **OpenAI GPT-5.6 Terra model/pricing:** https://developers.openai.com/api/docs/models/gpt-5.6-terra
- **OpenAI GPT-5.6 Luna model/pricing:** https://developers.openai.com/api/docs/models/gpt-5.6-luna
- **OpenAI GPT-Live 1 model/pricing:** https://developers.openai.com/api/docs/models/gpt-live-1
- **OpenAI Live WebRTC session creation:** https://developers.openai.com/api/reference/typescript/resources/live/methods/create
- **OpenAI Realtime client secrets:** https://developers.openai.com/api/reference/cli/resources/realtime/subresources/client_secrets
- **OpenAI transcription API/model list:** https://developers.openai.com/api/reference/cli/resources/audio/subresources/transcriptions/methods/create
- **OpenAI GPT-Transcribe pricing:** https://developers.openai.com/api/docs/models/gpt-transcribe
- **OpenAI API prepaid billing:** https://help.openai.com/en/articles/8264644
- **OpenAI projects/spend limits:** https://help.openai.com/en/articles/9186755
- **OpenAI API usage review:** https://help.openai.com/en/articles/10478918
- **GitHub pricing:** https://github.com/pricing
- **GitHub Actions billing:** https://docs.github.com/en/billing/concepts/product-billing/github-actions
- **GitHub Actions runner pricing:** https://docs.github.com/en/billing/reference/actions-runner-pricing
- **Next.js PWA guide:** https://nextjs.org/docs/app/guides/progressive-web-apps
- **Next.js installation requirements:** https://nextjs.org/docs/app/getting-started/installation
- **Next.js release/security blog:** https://nextjs.org/blog
- **Node.js release status:** https://nodejs.org/en/about/previous-releases
- **Python 3.13.15 release:** https://www.python.org/downloads/release/python-31315/
- **FastAPI release notes:** https://fastapi.tiangolo.com/release-notes/
- **FastAPI Docker deployment:** https://fastapi.tiangolo.com/deployment/docker/
- **Supabase pricing:** https://supabase.com/pricing
- **Supabase billing/limits:** https://supabase.com/docs/guides/platform/billing-on-supabase
- **Supabase database size limits:** https://supabase.com/docs/guides/platform/database-size
- **Cloudflare R2 pricing:** https://developers.cloudflare.com/r2/pricing/
- **Cloudflare R2 getting started:** https://developers.cloudflare.com/r2/get-started/
- **DigitalOcean Droplet pricing:** https://www.digitalocean.com/pricing/droplets
- **DigitalOcean Droplet pricing docs:** https://docs.digitalocean.com/products/droplets/details/pricing/
- **Docker Engine Ubuntu install:** https://docs.docker.com/engine/install/ubuntu/
- **Docker Compose model:** https://docs.docker.com/compose/intro/compose-application-model/
- **Caddy automatic HTTPS:** https://caddyserver.com/docs/automatic-https
- **Caddy reverse proxy:** https://caddyserver.com/docs/quick-starts/reverse-proxy
- **Redis Open Source 8.10 release notes:** https://redis.io/docs/latest/operate/oss_and_stack/stack-with-enterprise/release-notes/redisce/redisos-8.10-release-notes/
- **Redis Docker install:** https://redis.io/docs/latest/operate/oss_and_stack/install/install-stack/docker/
- **Celery 5.6 documentation:** https://docs.celeryq.dev/en/stable/getting-started/
- **FFmpeg downloads/releases:** https://ffmpeg.org/download.html
- **OpenCV releases:** https://opencv.org/releases/
- **Better Stack pricing:** https://betterstack.com/pricing
- **Better Stack heartbeat docs:** https://betterstack.com/docs/uptime/cron-and-heartbeat-monitor/
- **restic S3-compatible backend:** https://restic.readthedocs.io/en/latest/030_preparing_a_new_repo.html
- **restic restore docs:** https://restic.readthedocs.io/en/stable/050_restore.html
- **Runpod pricing:** https://www.runpod.io/pricing
- **Runpod Serverless:** https://www.runpod.io/product/serverless

## Notes on configurable facts
The following must remain configuration/operational checks rather than eternal constants:
- OpenAI model aliases/prices and promotional pricing dates;
- provider billing limits and free-tier quotas;
- DigitalOcean regional plan availability/tax;
- GitHub Actions quotas/rates;
- Supabase Free pause/quota behavior;
- R2 free tier and request pricing;
- Better Stack free monitor frequency/allowance;
- Runpod GPU SKU/rate availability;
- platform/campaign posting/analytics rules.

C00 freezes the architecture and selected starting route, not the claim that provider commerce never changes.

## Round-2 auth re-verification — 2026-09-20
- Supabase SSR overview: https://supabase.com/docs/guides/auth/server-side — cookie-backed SSR sessions; PKCE guidance.
- Supabase Next.js tutorial token-hash confirmation: https://supabase.com/docs/guides/getting-started/tutorials/with-nextjs — server `/auth/confirm` using `token_hash` + `verifyOtp`.
- Supabase email templates: https://supabase.com/docs/guides/auth/auth-email-templates — `TokenHash`, invite/recovery templates, server-side verification pattern.
- Supabase `verifyOtp`: https://supabase.com/docs/reference/javascript/auth-verifyotp — token-hash verification supported.
- Supabase server package selection: https://supabase.com/docs/guides/auth/choosing-a-server-package — `@supabase/ssr` for cookie sessions and refresh-token rotation.
No official source required reintroducing a V1 authorization-code callback; the token-hash Invite/Recovery design therefore remains frozen.

## Round-2 contradiction re-verification — 2026-09-20
- Supabase SSR: https://supabase.com/docs/guides/auth/server-side — cookie-backed SSR sessions; PKCE is the SSR default where applicable.
- Supabase Next.js tutorial: https://supabase.com/docs/guides/getting-started/tutorials/with-nextjs — server-side `/auth/confirm` token-hash `verifyOtp` pattern.
- Supabase email templates: https://supabase.com/docs/guides/auth/auth-email-templates — `TokenHash` supports custom server-side invite/confirmation links.
- Supabase password auth: https://supabase.com/docs/guides/auth/passwords — reset-password flow and non-enumerating reset request behavior.
- Supabase DB connections: https://supabase.com/docs/guides/database/connecting-to-postgres — direct IPv6 connection is appropriate for persistent VM/Droplet backends; shared pooler is the IPv4 alternative.
- Redis security: https://redis.io/docs/latest/operate/oss_and_stack/management/security/ — Redis authentication requirement; `requirepass` remains supported, while Redis ACLs are the broader fine-grained mechanism. HONOR V1 deliberately freezes the simpler `requirepass` mechanism on a non-public Compose network.

## Round-3 credential-scope verification note
Cloudflare R2 authentication/token page last-updated Aug 18, 2026 documents S3 Access Key ID + Secret Access Key credentials, `Object Read & Write`, and optional scoping to specific buckets. HONOR therefore freezes two separate specific-bucket credentials (`honor-media`, `honor-backups`) at no additional HONOR service-tier cost. Supabase current email-template documentation continues to document `{{ .TokenHash }}` links and server-side `verifyOtp`, and the Dashboard user guide continues to document Authentication -> Users -> Add user -> Send invitation.
