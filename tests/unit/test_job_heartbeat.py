from __future__ import annotations
import asyncio, os, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'services/worker'))
from honor_worker import durable_jobs

class FakeConn:
    def __init__(self): self.closed=False
    async def close(self): self.closed=True


def test_long_job_renews_multiple_times_and_stops_on_success(monkeypatch):
    renewals=[]; conn=FakeConn()
    async def factory(): return conn
    async def heartbeat(_conn,jid,token): renewals.append(asyncio.get_running_loop().time()); return True
    monkeypatch.setattr(durable_jobs,'heartbeat_on_connection',heartbeat)
    async def run():
        async def work(): await asyncio.sleep(0.12); return 'ok'
        result=await durable_jobs.run_with_job_heartbeat('j','t',work,interval=0.03,connection_factory=factory)
        count=len(renewals); await asyncio.sleep(0.07)
        return result,count,len(renewals)
    result,count,after=asyncio.run(run())
    assert result=='ok' and count >= 3 and after == count and conn.closed


def test_heartbeat_stops_when_work_fails(monkeypatch):
    renewals=[]; conn=FakeConn()
    async def factory(): return conn
    async def heartbeat(*_): renewals.append(1); return True
    monkeypatch.setattr(durable_jobs,'heartbeat_on_connection',heartbeat)
    async def run():
        async def work(): await asyncio.sleep(0.07); raise durable_jobs.RetryableJobError('fixture')
        try: await durable_jobs.run_with_job_heartbeat('j','t',work,interval=0.02,connection_factory=factory)
        except durable_jobs.RetryableJobError: pass
        count=len(renewals); await asyncio.sleep(0.05); return count,len(renewals)
    before,after=asyncio.run(run())
    assert before >= 2 and after == before and conn.closed


def test_heartbeat_failure_is_not_silently_ignored(monkeypatch):
    conn=FakeConn(); calls=0
    async def factory(): return conn
    async def heartbeat(*_):
        nonlocal calls; calls+=1; return False
    monkeypatch.setattr(durable_jobs,'heartbeat_on_connection',heartbeat)
    async def run():
        async def work(): await asyncio.sleep(1)
        try:
            await durable_jobs.run_with_job_heartbeat('j','t',work,interval=0.01,connection_factory=factory)
        except durable_jobs.JobHeartbeatError: return True
        return False
    assert asyncio.run(run()) is True and calls == 1


def test_production_heartbeat_interval_is_clamped_to_frozen_max(monkeypatch):
    monkeypatch.setenv('HONOR_JOB_HEARTBEAT_INTERVAL_SECONDS','99')
    assert durable_jobs.job_heartbeat_interval_seconds() == 30.0
