from datetime import datetime
from hashlib import sha256
import json
from pathlib import Path
from uuid import UUID, uuid4

from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[3]
REGISTRY_PATH = ROOT / "packages/contracts/polli-tools/HONOR_POLLI_TOOL_SCHEMAS.json"


class PolliRegistry:
    def __init__(self, path=REGISTRY_PATH):
        self.raw = json.loads(Path(path).read_text())
        self.tools = self.raw["tools"]
        if len(self.tools) != 12:
            raise RuntimeError("Polli registry must contain exactly 12 tools")
        for name, spec in self.tools.items():
            if spec["metadata"].get("read_only") is not True:
                raise RuntimeError(f"Polli tool is not read-only: {name}")

    def names(self):
        return tuple(self.tools.keys())

    def validate_arguments(self, name, args):
        if name not in self.tools:
            raise ValueError("tool not allowlisted")
        Draft202012Validator(
            self.tools[name]["arguments_schema"], format_checker=FormatChecker()
        ).validate(args)

    def validate_result(self, name, result):
        Draft202012Validator(
            self.tools[name]["result_schema"], format_checker=FormatChecker()
        ).validate(result)


class DenyByDefaultRateLimitHook:
    async def check(self, owner_id: str, tool_name: str) -> bool:
        # A real server-side limiter must be supplied before any handler can execute.
        return False


class NullAuditHook:
    async def record(self, **event):
        return None


class PolliGateway:
    FORBIDDEN_CAPABILITIES = frozenset(
        {"sql", "shell", "http", "cloud-admin", "mutation"}
    )

    def __init__(self, registry=None, rate_limit=None, audit=None):
        self.registry = registry or PolliRegistry()
        self.handlers = {}
        self.rate_limit = rate_limit or DenyByDefaultRateLimitHook()
        self.audit = audit or NullAuditHook()

    def register_read_only(self, name, handler):
        if name not in self.registry.tools:
            raise ValueError("not allowlisted")
        self.handlers[name] = handler

    async def call(self, name, args, *, owner_id: str, request_id: str):
        UUID(owner_id)
        UUID(request_id)
        self.registry.validate_arguments(name, args)
        if not await self.rate_limit.check(owner_id, name):
            raise PermissionError("RATE_LIMITED")
        await self.audit.record(
            event="POLLI_TOOL_CALLED",
            owner_id=owner_id,
            tool_name=name,
            request_id=request_id,
        )
        if name not in self.handlers:
            raise NotImplementedError(
                "tool data handler belongs to a later checkpoint"
            )
        result = await self.handlers[name](args)
        self.registry.validate_result(name, result)
        return result


class PolliPersistence:
    def __init__(self, conn):
        self.conn = conn

    async def start_session(
        self, *, owner_id: str, mode: str, backend_model_route: str
    ) -> str:
        session_id = uuid4()
        await self.conn.execute(
            """
            INSERT INTO polli_sessions(
              id,user_id,mode,started_at,backend_model_route,retention_mode,status
            ) VALUES($1,$2,$3,statement_timestamp(),$4,'TRANSCRIPT_SUMMARY','ACTIVE')
            """,
            session_id,
            owner_id,
            mode,
            backend_model_route,
        )
        return str(session_id)

    async def record_tool_call(
        self,
        *,
        session_id: str,
        turn_id: str | None,
        tool_name: str,
        args: dict,
        result_summary: dict,
        owner_id: str,
        started_at: datetime,
        finished_at: datetime,
    ) -> str:
        digest = sha256(
            json.dumps(result_summary, sort_keys=True, separators=(",", ":")).encode()
        ).hexdigest()
        call_id = uuid4()
        await self.conn.execute(
            """
            INSERT INTO polli_tool_calls(
              id,session_id,turn_id,tool_name,tool_version,arguments_json,
              result_digest,result_summary_json,authorized_by,started_at,finished_at,status
            ) VALUES($1,$2,$3,$4,1,$5,$6,$7,$8,$9,$10,'SUCCEEDED')
            """,
            call_id,
            session_id,
            turn_id,
            tool_name,
            args,
            digest,
            result_summary,
            owner_id,
            started_at,
            finished_at,
        )
        return str(call_id)
