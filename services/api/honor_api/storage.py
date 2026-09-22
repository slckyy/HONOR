from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path
from urllib.parse import quote
from urllib.parse import unquote

import boto3

from .config import get_settings


@dataclass(frozen=True)
class StoredObject:
    key: str
    sha256: str
    bytes: int
    content_type: str


_ALLOWED_PREFIXES = ("sources/", "renders/", "evidence/", "uploads/", "polli/")


def _validated_key(key: str) -> str:
    normalized = key.replace("\\", "/")
    if normalized.startswith("/") or "\x00" in normalized:
        raise ValueError("invalid object key")
    if not any(normalized.startswith(prefix) for prefix in _ALLOWED_PREFIXES):
        raise ValueError("unapproved storage prefix")
    parts = normalized.split("/")
    if any(part in {"", ".", ".."} for part in parts):
        raise ValueError("invalid object key")
    return normalized


def safe_key(prefix: str, name: str) -> str:
    if prefix not in _ALLOWED_PREFIXES:
        raise ValueError("unapproved storage prefix")
    normalized = name.replace("\\", "/")
    return _validated_key(prefix + normalized)


class Storage(ABC):
    @abstractmethod
    def put(self, key: str, data: bytes, content_type: str) -> StoredObject: ...

    @abstractmethod
    def get(self, key: str) -> bytes: ...

    @abstractmethod
    def delete(self, key: str) -> None: ...

    @abstractmethod
    def presign_get(self, key: str, ttl: int) -> str: ...

    @abstractmethod
    def presign_put(self, key: str, ttl: int, content_type: str) -> str: ...


class LocalStorage(Storage):
    """Development/test adapter only. Production selection never falls back here."""

    def __init__(self, root: str):
        self.root = Path(root).resolve()
        self.root.mkdir(parents=True, exist_ok=True)

    def _path(self, key: str) -> Path:
        key = _validated_key(key)
        path = (self.root / key).resolve()
        if self.root not in path.parents:
            raise ValueError("unsafe path")
        return path

    def put(self, key: str, data: bytes, content_type: str) -> StoredObject:
        key = _validated_key(key)
        path = self._path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return StoredObject(key, sha256(data).hexdigest(), len(data), content_type)

    def get(self, key: str) -> bytes:
        return self._path(key).read_bytes()

    def delete(self, key: str) -> None:
        self._path(key).unlink(missing_ok=True)

    def presign_get(self, key: str, ttl: int) -> str:
        key = _validated_key(key)
        return f"/__dev/storage/{quote(key, safe='')}?operation=get&ttl={int(ttl)}"

    def presign_put(self, key: str, ttl: int, content_type: str) -> str:
        key = _validated_key(key)
        encoded_type = quote(content_type, safe="")
        return (
            f"/__dev/storage/{quote(key, safe='')}?operation=put&ttl={int(ttl)}"
            f"&content_type={encoded_type}"
        )


class R2Storage(Storage):
    def __init__(self):
        settings = get_settings()
        if not all(
            [
                settings.R2_ENDPOINT,
                settings.R2_MEDIA_ACCESS_KEY_ID,
                settings.R2_MEDIA_SECRET_ACCESS_KEY,
                settings.R2_BUCKET_MEDIA,
            ]
        ):
            raise RuntimeError("R2 media configuration is incomplete")
        self.bucket = settings.R2_BUCKET_MEDIA
        self.client = boto3.client(
            "s3",
            endpoint_url=settings.R2_ENDPOINT,
            aws_access_key_id=settings.R2_MEDIA_ACCESS_KEY_ID,
            aws_secret_access_key=settings.R2_MEDIA_SECRET_ACCESS_KEY,
            region_name="auto",
        )

    def put(self, key: str, data: bytes, content_type: str) -> StoredObject:
        key = _validated_key(key)
        digest = sha256(data).hexdigest()
        self.client.put_object(
            Bucket=self.bucket,
            Key=key,
            Body=data,
            ContentType=content_type,
            Metadata={"sha256": digest},
        )
        return StoredObject(key, digest, len(data), content_type)

    def get(self, key: str) -> bytes:
        key = _validated_key(key)
        return self.client.get_object(Bucket=self.bucket, Key=key)["Body"].read()

    def delete(self, key: str) -> None:
        key = _validated_key(key)
        self.client.delete_object(Bucket=self.bucket, Key=key)

    def presign_get(self, key: str, ttl: int) -> str:
        key = _validated_key(key)
        return self.client.generate_presigned_url(
            "get_object",
            Params={"Bucket": self.bucket, "Key": key},
            ExpiresIn=int(ttl),
        )

    def presign_put(self, key: str, ttl: int, content_type: str) -> str:
        key = _validated_key(key)
        return self.client.generate_presigned_url(
            "put_object",
            Params={"Bucket": self.bucket, "Key": key, "ContentType": content_type},
            ExpiresIn=int(ttl),
        )


def storage() -> Storage:
    settings = get_settings()
    if settings.HONOR_ENV.lower() == "production":
        # Production is frozen to R2. There is deliberately no local-disk fallback flag.
        return R2Storage()
    return LocalStorage("/tmp/honor-media")


def storage_ready() -> bool:
    try:
        selected = storage()
        if isinstance(selected, R2Storage):
            selected.client.head_bucket(Bucket=selected.bucket)
        return True
    except Exception:
        return False
