import os
os.environ.setdefault('HONOR_OWNER_USER_ID','00000000-0000-0000-0000-000000000001');os.environ.setdefault('SUPABASE_URL','https://example.supabase.co');os.environ.setdefault('SUPABASE_JWKS_URL','https://example.supabase.co/auth/v1/.well-known/jwks.json');os.environ.setdefault('DATABASE_APP_URL','postgresql://x:x@localhost/x');os.environ.setdefault('REDIS_PASSWORD','dev-only-redis-password-0123456789abcdef')
from fastapi.testclient import TestClient
from honor_api.app import create_app

def test_healthz():
    r=TestClient(create_app()).get('/healthz');assert r.status_code==200;assert r.json()['status']=='ok';assert r.json()['service']=='honor-api'
def test_readyz_requires_auth():assert TestClient(create_app()).get('/readyz').status_code==401
