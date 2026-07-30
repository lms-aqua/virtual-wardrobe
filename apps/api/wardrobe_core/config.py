"""Typed application settings.

All configuration comes from the environment (12-factor). Nothing sensitive is
hard-coded. Pydantic validates types and fails fast on startup if something is
malformed, so a misconfigured secret cannot silently weaken security.
"""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, computed_field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # ---- Environment ----
    wardrobe_env: Literal["development", "staging", "production"] = "development"
    log_level: str = "INFO"

    # ---- API / security ----
    secret_key: str = Field(min_length=16)
    cors_origins: str = "http://localhost:3000"
    session_cookie_name: str = "vw_session"
    session_ttl_seconds: int = 1_209_600
    session_cookie_secure: bool = False

    # ---- Postgres ----
    postgres_host: str = "postgres"
    postgres_port: int = 5432
    postgres_db: str = "wardrobe"
    postgres_user: str = "wardrobe"
    postgres_password: str = "change-me-postgres"
    database_url: str = ""

    # ---- Redis ----
    redis_host: str = "redis"
    redis_port: int = 6379
    redis_url: str = ""

    # ---- Object storage ----
    s3_endpoint_url: str = "http://minio:9000"
    s3_public_endpoint_url: str = "http://localhost:9000"
    s3_region: str = "us-east-1"
    s3_access_key: str = "change-me-minio-access"
    s3_secret_key: str = "change-me-minio-secret"
    s3_bucket_scans: str = "vw-scans-private"
    s3_bucket_avatars: str = "vw-avatars-private"
    s3_bucket_garments: str = "vw-garments-private"
    s3_signed_url_ttl_seconds: int = 300

    # ---- Uploads ----
    max_upload_bytes: int = 15_728_640
    allowed_image_mime: str = "image/jpeg,image/png,image/heic"

    # ---- Auth ----
    magic_link_ttl_seconds: int = 900
    smtp_host: str = "mailhog"
    smtp_port: int = 1025
    smtp_from: str = "no-reply@virtualwardrobe.local"
    apple_client_id: str = ""
    apple_team_id: str = ""
    apple_key_id: str = ""
    apple_private_key: str = ""

    # ---- Privacy ----
    delete_raw_scans_after_avatar: bool = True

    # ---- Jobs ----
    # When true, scan processing runs synchronously in-request (dev/test). In
    # production this is false and work is dispatched to the Dramatiq worker.
    run_jobs_inline: bool = True

    @computed_field  # type: ignore[prop-decorator]
    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @computed_field  # type: ignore[prop-decorator]
    @property
    def allowed_image_mime_set(self) -> set[str]:
        return {m.strip().lower() for m in self.allowed_image_mime.split(",") if m.strip()}

    @computed_field  # type: ignore[prop-decorator]
    @property
    def sqlalchemy_url(self) -> str:
        if self.database_url:
            return self.database_url
        return (
            f"postgresql+asyncpg://{self.postgres_user}:{self.postgres_password}"
            f"@{self.postgres_host}:{self.postgres_port}/{self.postgres_db}"
        )

    @computed_field  # type: ignore[prop-decorator]
    @property
    def effective_redis_url(self) -> str:
        return self.redis_url or f"redis://{self.redis_host}:{self.redis_port}/0"

    @computed_field  # type: ignore[prop-decorator]
    @property
    def is_production(self) -> bool:
        return self.wardrobe_env == "production"


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore[call-arg]
