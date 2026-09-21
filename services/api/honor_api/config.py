from __future__ import annotations

from functools import lru_cache
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore", case_sensitive=True)

    HONOR_ENV: str = "development"
    LOG_LEVEL: str = "INFO"
    HONOR_OWNER_USER_ID: str = Field(min_length=36)
    HONOR_UPLOAD_MAX_BYTES: int = 2_147_483_648

    SUPABASE_URL: str
    SUPABASE_JWKS_URL: str
    DATABASE_APP_URL: str

    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: str = Field(min_length=32)
    REDIS_CACHE_DB: int = 0
    CELERY_BROKER_DB: int = 1
    CELERY_RESULT_DB: int = 2

    R2_ENDPOINT: str = ""
    R2_BUCKET_MEDIA: str = "honor-media"
    R2_MEDIA_ACCESS_KEY_ID: str = ""
    R2_MEDIA_SECRET_ACCESS_KEY: str = ""
    R2_PRESIGNED_URL_TTL_SECONDS: int = Field(default=300, ge=60, le=900)

    HONOR_MONTH1_HARD_CAP_USD: str = "56.03"
    HONOR_OPTIONAL_PAUSE_USD: str = "43.00"
    HONOR_RESERVE_MODE_USD: str = "51.03"

    @property
    def redis_url(self) -> str:
        return (
            f"redis://:{self.REDIS_PASSWORD}@{self.REDIS_HOST}:"
            f"{self.REDIS_PORT}/{self.REDIS_CACHE_DB}"
        )


@lru_cache
def get_settings() -> Settings:
    return Settings()
