from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
required = [
    'apps/web/app','services/api/honor_api','services/worker/honor_worker','services/intelligence/honor_intelligence','services/media/honor_media',
    'packages/contracts/openapi','packages/contracts/jsonschema','packages/contracts/events','packages/contracts/polli-tools','packages/contracts/generated','packages/design-system/src',
    'infrastructure/docker','infrastructure/migrations','infrastructure/deployment/scripts','infrastructure/deployment/systemd','infrastructure/runbooks','infrastructure/backup','infrastructure/monitoring',
    'tests/unit','tests/integration','tests/contract','tests/e2e','docs/architecture','docs/operations','docs/security','docs/decisions','.github/workflows'
]
for p in required:
    assert (ROOT / p).exists(), p
assert not (ROOT / 'apps/web/app/auth/callback').exists()
assert len(list((ROOT / 'packages/contracts/jsonschema').glob('*.json'))) == 30
assert len(json.loads((ROOT / 'packages/contracts/polli-tools/HONOR_POLLI_TOOL_SCHEMAS.json').read_text())['tools']) == 12

caddy = (ROOT / 'infrastructure/Caddyfile').read_text()
assert 'api:8000' in caddy and 'reverse_proxy web:3000' in caddy
assert 'handle_path /v1' not in caddy and '@v1' not in caddy
assert '{$HONOR_PUBLIC_HOST}' in caddy and ':localhost' not in caddy

prod = json.loads((ROOT / 'infrastructure/docker/compose.production.yml').read_text())
assert 'ports' not in prod['services']['redis']
assert 'ports' not in prod['services']['api']
assert 'ports' not in prod['services']['worker']
assert 'ports' not in prod['services']['reconciler']
assert 'reconciler' in prod['services']
assert '/opt/honor/secrets/runtime.env' not in (ROOT / 'infrastructure/docker/compose.production.yml').read_text()

sql = (ROOT / 'infrastructure/migrations/0002_runtime_security.sql').read_text()
assert 'FORCE ROW LEVEL SECURITY' in sql and 'REVOKE DELETE ON ALL TABLES' in sql
assert '56.03' in (ROOT / '.env.example').read_text() and 'HONOR_MONTH1_HARD_CAP_USD=56.03' in (ROOT / '.env.example').read_text()

# C00 migration remains byte-identical to the approved source.
import hashlib
assert hashlib.sha256((ROOT / 'docs/architecture/c00-approved/HONOR_DATABASE_CONTRACT.sql').read_bytes()).digest() == hashlib.sha256((ROOT / 'infrastructure/migrations/0001_c00_database_contract.sql').read_bytes()).digest()

subprocess.run([sys.executable, str(ROOT / 'scripts/check_contract_drift.py')], check=True)
subprocess.run([sys.executable, str(ROOT / 'scripts/secret_scan.py')], check=True)
print('OK: C01 static acceptance checks passed')
