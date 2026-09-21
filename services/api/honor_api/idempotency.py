from hashlib import sha256
import json
from uuid import uuid4


def request_hash(body: bytes) -> str:
    return sha256(body).hexdigest()


def canonical_response_hash(body: dict) -> str:
    return sha256(
        json.dumps(body, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


class IdempotencyRepository:
    def __init__(self, conn):
        self.conn = conn

    async def find(self, owner_user_id: str, key: str):
        row = await self.conn.fetchrow(
            "SELECT * FROM api_idempotency_records WHERE owner_user_id=$1::uuid AND idempotency_key=$2",
            owner_user_id,
            key,
        )
        return dict(row) if row else None

    async def record(
        self,
        *,
        owner_user_id: str,
        key: str,
        method: str,
        path: str,
        request_sha256: str,
        response_status: int,
        response_body: dict,
        ttl_seconds: int = 86400,
    ):
        existing = await self.find(owner_user_id, key)
        if existing:
            if (
                existing["request_sha256"] != request_sha256
                or existing["http_method"] != method
                or existing["path"] != path
            ):
                raise ValueError("IDEMPOTENCY_KEY_REUSED")
            return existing
        row = await self.conn.fetchrow(
            """
            INSERT INTO api_idempotency_records(
              id,owner_user_id,idempotency_key,http_method,path,request_sha256,
              response_status,response_body,expires_at
            ) VALUES($1,$2::uuid,$3,$4,$5,$6,$7,$8,statement_timestamp()+($9||' seconds')::interval)
            RETURNING *
            """,
            uuid4(),
            owner_user_id,
            key,
            method,
            path,
            request_sha256,
            response_status,
            response_body,
            ttl_seconds,
        )
        return dict(row)
