from __future__ import annotations
import os, urllib.request


def _log(code: str, severity: str="INFO") -> None:
    print(f'{{"service":"worker-monitor","severity":"{severity}","event_code":"{code}"}}',flush=True)


def health_is_live() -> bool:
    try:
        from .celery_app import app
        replies=app.control.inspect(timeout=5).ping() or {}
        worker_live=any((payload or {}).get("ok")=="pong" for payload in replies.values())
        import redis
        pwd=os.environ["REDIS_PASSWORD"]
        host=os.getenv("REDIS_HOST","redis"); port=os.getenv("REDIS_PORT","6379"); db=os.getenv("REDIS_CACHE_DB","0")
        client=redis.from_url(f"redis://:{pwd}@{host}:{port}/{db}",socket_timeout=5,socket_connect_timeout=5)
        try:
            reconciler_live=client.get("honor:health:reconciler")==b"ok"
        finally:
            client.close()
        return worker_live and reconciler_live
    except Exception:
        return False


def run_once() -> bool:
    url=os.getenv("BETTERSTACK_WORKER_HEARTBEAT_URL","").strip()
    if not url:
        _log("WORKER_HEARTBEAT_DISABLED")
        return True
    if not health_is_live():
        _log("WORKER_HEARTBEAT_SUPPRESSED_UNHEALTHY","WARNING")
        return False
    try:
        with urllib.request.urlopen(urllib.request.Request(url,method="GET"),timeout=10) as response:
            if not (200 <= response.status < 300):
                raise RuntimeError("heartbeat response was not successful")
    except Exception:
        _log("WORKER_HEARTBEAT_SEND_FAILED","WARNING")
        return False
    _log("WORKER_HEARTBEAT_SENT")
    return True

if __name__=="__main__":
    raise SystemExit(0 if run_once() else 1)
