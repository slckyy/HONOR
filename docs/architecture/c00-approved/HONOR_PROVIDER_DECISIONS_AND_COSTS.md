> HONOR C00 frozen specification — research date 2026-09-20.
> Month-1 hard operating ceiling: $56.03 USD. Later builders may not silently change frozen contracts.

# Provider Decisions and Costs

All prices are research-time assumptions, not permanent truths. Re-verify official pricing immediately before any purchase or upgrade.

| Provider/service | Frozen use | Starting tier | Month-1 planned cost | Important limit/assumption |
|---|---|---:|---:|---|
| GitHub | canonical private repo + CI | Free | $0 | Unlimited private repos; 2,000 Actions minutes/month on Free; set metered budget to stop overage |
| DigitalOcean | always-on app/worker VPS | Basic Regular 4 GiB / 2 vCPU / 80 GiB | $24.00 | CPU render concurrency 1; region chosen near owner/users, default NYC/ATL-compatible US region based on availability |
| Supabase | Postgres + Auth | Free | $0 | 500 MB DB; free project can pause after inactivity; no automatic backups on Free |
| Cloudflare R2 | media + backup object storage | Standard | $0 expected | 10 GB-month free, 1M Class A, 10M Class B; egress free; billing subscription may require payment method |
| OpenAI API | transcription, Polli voice, reasoning | prepaid/project | <= $15.00 internal ceiling | auto-reload OFF; minimum prepaid purchase currently $5; provider budget is defense-in-depth |
| Better Stack | uptime + heartbeats | Free | $0 | 10 monitors + 10 heartbeats; free check frequency about 3 minutes |
| Redis | queue broker | self-hosted on VPS | $0 incremental | Redis 8.10.1; never source of truth |
| Docker/Caddy/restic | runtime/TLS/backup tooling | open source | $0 | owner pays only underlying compute/storage |
| Runpod | optional burst GPU | disabled | $0 | no account/endpoint required at launch; serverless can scale to zero; current lowest cited class ~$0.58/hr |
| Domain registrar | custom domain | deferred | $0 now | no purchase until deployment because exact name/price unknown |

## OpenAI cost allocation inside the $15 ceiling
This is an internal planning envelope, not a guaranteed spend:
- Polli voice reserve: up to **$7.50** for 5 minutes/day × 30 days × $0.05/minute, excluding backend model/tool calls.
- Transcription reserve: **$3.50**; at the researched `gpt-4o-mini-transcribe` estimate of ~$0.003/minute, that is roughly 1,166 minutes before retry/escalation costs.
- Text reasoning/tools reserve: **$2.00** using Luna by default.
- Slack within OpenAI allocation: **$2.00**.

If one subcategory is underused, the governor can reallocate within the same $15 global ceiling. It cannot exceed the global Month-1 cap.

## Full $56.03 governor
- Planned fixed DigitalOcean: $24.00.
- Maximum OpenAI allocation: $15.00.
- Provider/storage/tax/price drift contingency: $12.03.
- Emergency reserve: $5.00.
- Hard total: $56.03.

### Deterministic governor states
Machine authority: `HONOR_COST_GOVERNOR.json`. Admission uses `governor_exposure_usd`, not an optimistic provider dashboard or projected-month-end estimate.

- **NORMAL:** `governor_exposure_usd < $43.00`. Core and optional paid work may be admitted only when the deterministic reservation fits all remaining thresholds.
- **OPTIONAL_PAUSED:** `$43.00 <= governor_exposure_usd < $51.03`. **No new optional paid generation, optional reasoning, optional transcription experiments, optional Polli analysis, GPU experiments, or other discretionary provider spend may be admitted.** Already-required/core work may proceed only if the deterministic post-admission exposure remains below `$51.03`.
- **RESERVE:** `$51.03 <= governor_exposure_usd < $56.03`. Only explicitly permitted emergency/recovery/security/reconciliation paid expenditure may be admitted, and only if post-admission exposure remains below `$56.03`. Ordinary production work and all optional paid work are blocked.
- **HARD_STOP:** `governor_exposure_usd >= $56.03`. No new paid call/job/purchase may be admitted. Only zero-cost actions, reconciliation, owner review, and explicitly free operations may continue.

`governor_exposure_usd = cash_spend_counted_usd + unpaid_committed_usd + admitted_queued_unfunded_usd`. HONOR reserves conservative cost **before dispatch**, so provider reporting lag cannot defeat the cap. Prepaid funding counts in full at purchase time in `cash_spend_counted_usd`; later usage consuming already-counted credit is not counted again. Only queued/admitted cost beyond remaining already-counted prepaid credit increases `admitted_queued_unfunded_usd`. A pending refund never reduces exposure; only provider-confirmed settled refund evidence may do so.

No model is allowed to waive this rule.

## Pricing assumptions verified on 2026-09-20
- DigitalOcean listed 4 GiB / 2 vCPU Basic Regular at $24/month.
- GitHub Free listed 2,000 Actions minutes/month and unlimited private repositories.
- Supabase Free listed 500 MB DB and 50,000 MAU; Free projects can pause after one week inactivity.
- R2 Standard free tier listed 10 GB-month storage, 1M Class A, 10M Class B, no Internet egress charge.
- GPT-Live 1 listed $0.05/minute billed per second; backend model/tool usage billed separately.
- GPT-5.6 Luna listed $0.20/M input and $1.20/M output; Terra $2/M input and $12/M output; Sol currently promotional $4/M input and $20/M output at research time.
- OpenAI prepaid minimum purchase currently $5; auto-reload can be disabled.
- `gpt-4o-mini-transcribe` is listed as an available transcription model and OpenAI pricing documentation estimates roughly $0.003/minute.

## Cost confidence
- Fixed VPS price: HIGH at research date, but taxes/region changes may apply.
- Free-tier provider cost: MEDIUM; remains $0 only while usage stays within tier and provider terms do not change.
- OpenAI voice baseline: HIGH for connected minutes, MEDIUM for total Polli cost because backend calls vary.
- Transcription: MEDIUM; source duration and retries drive total.
- R2: MEDIUM; source/intermediate retention must be controlled.
- Domain: UNKNOWN until a name is chosen.

## What not to buy yet
- Supabase Pro.
- Managed Redis.
- DigitalOcean managed database/backup add-ons.
- Any always-on GPU.
- Runpod credits/endpoint.
- Paid Better Stack plan.
- Paid GitHub plan or Copilot solely for HONOR infrastructure.
- Premium CDN/video processing service.
- A domain until deployment requires it and price is approved.
