import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COMPOSE = json.loads((ROOT / "infrastructure/docker/compose.production.yml").read_text())
REGISTRY = json.loads(
    (ROOT / "docs/architecture/c00-approved/HONOR_SECRET_ENV_REGISTRY.json").read_text()
)

TEMPLATES = {
    "/opt/honor/secrets/redis.env": ROOT / "infrastructure/deployment/env/redis.env.example",
    "/opt/honor/secrets/api.env": ROOT / "infrastructure/deployment/env/api.env.example",
    "/opt/honor/secrets/worker.env": ROOT / "infrastructure/deployment/env/worker.env.example",
    "/opt/honor/secrets/reconciler.env": ROOT / "infrastructure/deployment/env/reconciler.env.example",
    "/opt/honor/secrets/migration.env": ROOT / "infrastructure/deployment/env/migration.env.example",
    "/opt/honor/secrets/bootstrap.env": ROOT / "infrastructure/deployment/env/bootstrap.env.example",
    "/opt/honor/secrets/worker-monitoring.env": ROOT / "infrastructure/deployment/env/worker-monitor.env.example",
    "/opt/honor/config/api.env": ROOT / "infrastructure/deployment/env/api.config.env.example",
    "/opt/honor/config/worker.env": ROOT / "infrastructure/deployment/env/worker.config.env.example",
    "/opt/honor/config/web.env": ROOT / "infrastructure/deployment/env/web.env.example",
    "/opt/honor/config/caddy.env": ROOT / "infrastructure/deployment/env/caddy.env.example",
}

# Compose service names mapped to frozen C00 receiver classes. Reconciler is a worker/Celery
# process but deliberately receives a narrower subset than the main worker.
SERVICE_RECEIVER_CLASSES = {
    "redis": {"redis"},
    "api": {"api", "polli"},
    "worker": {"worker", "celery", "media"},
    "reconciler": {"worker", "celery"},
    "web": {"web"},
    "caddy": {"caddy"},
    "migrate": {"migration"},
    "bootstrap-runtime-role": {"owner-bootstrap"},
    "worker-monitor": {"worker", "celery"},
}

NON_COMPOSE_SECRET_FILES = {
    "backup": ROOT / "infrastructure/deployment/env/backup.env.example",
}


def keys(path: Path) -> set[str]:
    result = set()
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        result.add(line.split("=", 1)[0])
    return result


def service_keys(service: str) -> set[str]:
    found = set()
    for env_file in COMPOSE["services"][service].get("env_file", []):
        assert env_file in TEMPLATES, f"unfrozen env receiver file {env_file}"
        found |= keys(TEMPLATES[env_file])
    environment = COMPOSE["services"][service].get("environment", {})
    if isinstance(environment, dict):
        found |= set(environment)
    return found


def test_every_compose_secret_is_allowed_by_frozen_receiver_registry():
    frozen = REGISTRY["credentials"]
    for service in COMPOSE["services"]:
        classes = SERVICE_RECEIVER_CLASSES[service]
        for secret in service_keys(service) & set(frozen):
            allowed = set(frozen[secret]["receivers"])
            # Repair Round 1 explicitly freezes REDIS_PASSWORD for the Redis server itself
            # in addition to the application/Celery receivers listed by C00.
            if secret == "REDIS_PASSWORD":
                allowed.add("redis")
            assert classes & allowed, (service, secret, classes, allowed)


def test_runtime_secret_receivers_are_exact_and_least_privilege():
    actual = {name: service_keys(name) for name in COMPOSE["services"]}
    expected = {
        "DATABASE_APP_URL": {"api", "worker", "reconciler"},
        "DATABASE_ADMIN_URL": {"migrate", "bootstrap-runtime-role"},
        "REDIS_PASSWORD": {"redis", "api", "worker", "reconciler", "worker-monitor"},
        "R2_MEDIA_ACCESS_KEY_ID": {"api", "worker"},
        "R2_MEDIA_SECRET_ACCESS_KEY": {"api", "worker"},
        "R2_BACKUP_ACCESS_KEY_ID": set(),
        "R2_BACKUP_SECRET_ACCESS_KEY": set(),
        "OPENAI_API_KEY": {"api", "worker"},
        "BETTERSTACK_API_TOKEN": set(),
        "BETTERSTACK_BACKUP_HEARTBEAT_URL": set(),
        "BETTERSTACK_WORKER_HEARTBEAT_URL": {"worker-monitor"},
        "RESTIC_PASSWORD": set(),
        "RUNPOD_API_KEY": set(),
        "DEPLOY_SSH_PRIVATE_KEY": set(),
    }
    for secret in REGISTRY["credentials"]:
        receivers = {service for service, env in actual.items() if secret in env}
        assert receivers == expected[secret], (secret, receivers, expected[secret])


def test_backup_template_contains_only_backup_restic_allowed_credentials():
    frozen = REGISTRY["credentials"]
    present = keys(NON_COMPOSE_SECRET_FILES["backup"]) & set(frozen)
    assert present == {
        "DATABASE_ADMIN_URL",
        "R2_BACKUP_ACCESS_KEY_ID",
        "R2_BACKUP_SECRET_ACCESS_KEY",
        "RESTIC_PASSWORD",
        "BETTERSTACK_BACKUP_HEARTBEAT_URL",
    }
    for secret in present:
        allowed = set(frozen[secret]["receivers"])
        assert allowed & {"backup", "restic"}


def test_web_and_caddy_receive_no_frozen_credentials():
    forbidden = set(REGISTRY["credentials"])
    assert service_keys("web").isdisjoint(forbidden)
    assert service_keys("caddy").isdisjoint(forbidden)
    assert service_keys("caddy") == {"HONOR_PUBLIC_HOST"}


def test_admin_and_backup_credentials_are_not_runtime_shared():
    runtime = {"redis", "api", "worker", "reconciler", "worker-monitor", "web", "caddy"}
    for service in runtime:
        assert "DATABASE_ADMIN_URL" not in service_keys(service)
        assert "R2_BACKUP_ACCESS_KEY_ID" not in service_keys(service)
        assert "R2_BACKUP_SECRET_ACCESS_KEY" not in service_keys(service)
        assert "RESTIC_PASSWORD" not in service_keys(service)
