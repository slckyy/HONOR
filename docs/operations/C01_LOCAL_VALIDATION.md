# C01 local validation

Core no-provider checks:

```bash
python3 scripts/check_contract_drift.py
python3 scripts/secret_scan.py
python3 scripts/static_acceptance.py
PYTHONPATH=services/api:services/worker:services/media:services/intelligence pytest -q tests services/api/tests services/worker/tests services/media/tests services/intelligence/tests
```

With Docker/Postgres/Redis installed, run the full CI-equivalent stack and integration tests. Live Supabase/R2/OpenAI/DigitalOcean/Better Stack checks are intentionally not required to run C01 unit/contract tests.
