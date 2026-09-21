from __future__ import annotations
import json, re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


def test_web_public_config_is_explicit_build_time_contract():
    dockerfile=(ROOT/'apps/web/Dockerfile').read_text()
    runtime=(ROOT/'infrastructure/deployment/env/web.env.example').read_text()
    for key in ('NEXT_PUBLIC_SUPABASE_URL','NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY','NEXT_PUBLIC_HONOR_BFF_BASE'):
        assert f'ARG {key}' in dockerfile
        assert key not in {line.split('=',1)[0] for line in runtime.splitlines() if '=' in line and not line.lstrip().startswith('#')}
    build_index=dockerfile.index('npm --workspace @honor/web run build')
    assert dockerfile.index('ARG NEXT_PUBLIC_SUPABASE_URL') < build_index
    assert 'runtime web.env cannot replace' not in runtime.lower() or 'frozen' in runtime.lower()


def test_web_image_build_args_are_public_only():
    dockerfile=(ROOT/'apps/web/Dockerfile').read_text()
    forbidden=('DATABASE_','REDIS_','R2_','OPENAI_','RESTIC_','DEPLOY_','BETTERSTACK_')
    args=re.findall(r'^ARG\s+([A-Z0-9_]+)',dockerfile,re.M)
    assert set(args) == {'NEXT_PUBLIC_SUPABASE_URL','NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY','NEXT_PUBLIC_HONOR_BFF_BASE'}
    assert all(not any(arg.startswith(prefix) for prefix in forbidden) for arg in args)


def test_first_deploy_bootstrap_precedes_runtime_activation_and_health_is_not_readiness():
    deploy=(ROOT/'infrastructure/deployment/scripts/deploy.sh').read_text()
    assert deploy.index('apply-migrations.sh') < deploy.index('provision-runtime-role.sh') < deploy.index('up -d --remove-orphans redis api worker reconciler worker-monitor web caddy')
    assert deploy.index('/healthz') < deploy.index('verify-runtime-db.sh')
    assert 'ROLE_SENTINEL' in deploy
    provision=deploy.index('provision-runtime-role.sh')
    remove=deploy.index('rm -f /opt/honor/secrets/bootstrap.env')
    activate=deploy.index('up -d --remove-orphans redis api worker reconciler worker-monitor web caddy')
    assert provision < remove < activate


def test_monitoring_is_invoked_by_production_topology():
    compose=json.loads((ROOT/'infrastructure/docker/compose.production.yml').read_text())
    monitor=compose['services']['worker-monitor']
    assert monitor['command'] == ['/app/infrastructure/monitoring/worker-heartbeat.sh']
    assert '/opt/honor/secrets/worker-monitoring.env' in monitor['env_file']
    assert set(monitor['depends_on']) >= {'worker','reconciler'}
    worker_image=(ROOT/'services/worker/Dockerfile').read_text()
    assert 'infrastructure/monitoring/worker-heartbeat.sh' in worker_image


def test_heartbeat_production_configuration_is_at_most_30_seconds():
    config=(ROOT/'infrastructure/deployment/env/worker.config.env.example').read_text()
    match=re.search(r'^HONOR_JOB_HEARTBEAT_INTERVAL_SECONDS=(\d+)$',config,re.M)
    assert match and 0 < int(match.group(1)) <= 30
