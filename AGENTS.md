# HONOR Builder Rules

1. Read `docs/architecture/c00-approved/HONOR_CANONICAL_HANDOFF.md` before changing architecture.
2. C00 Round-12 is authoritative. Never weaken database, auth, budget, rights, provenance, owner-review, Polli, or manual-posting invariants silently.
3. Browser application traffic is browser -> Next.js BFF -> private FastAPI. Do not expose FastAPI `/v1/*` publicly.
4. PostgreSQL is durable job truth. Redis is dispatch/coordination only.
5. V1 social posting is manual.
6. `$4,000/month` is target progress only, never a forecast.
7. Never commit or log secrets. Never add unrestricted SQL/shell/arbitrary-HTTP Polli tools.
8. If a frozen contract genuinely cannot work, emit a CHANGE REQUEST; do not redesign it in-place.
