from __future__ import annotations
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'services/worker'))


def test_monitor_disabled_without_optional_url(monkeypatch):
    monkeypatch.setenv('REDIS_PASSWORD','x'*32)
    monkeypatch.delenv('BETTERSTACK_WORKER_HEARTBEAT_URL',raising=False)
    from honor_worker import monitoring
    assert monitoring.run_once() is True


def test_monitor_suppresses_success_when_worker_or_reconciler_unhealthy(monkeypatch):
    monkeypatch.setenv('REDIS_PASSWORD','x'*32)
    monkeypatch.setenv('BETTERSTACK_WORKER_HEARTBEAT_URL','https://secret.invalid/heartbeat')
    from honor_worker import monitoring
    monkeypatch.setattr(monitoring,'health_is_live',lambda: False)
    called=[]
    monkeypatch.setattr(monitoring.urllib.request,'urlopen',lambda *a,**k: called.append(1))
    assert monitoring.run_once() is False and called == []
