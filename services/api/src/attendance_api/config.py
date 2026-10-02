from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


def _model_path(filename: str) -> str:
    candidates = (Path("models") / filename, Path("../../models") / filename)
    return str(next((path for path in candidates if path.is_file()), candidates[0]))


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=(".env", "../../.env"), extra="ignore")

    app_env: Literal["development", "test", "production"] = "development"
    auth_provider: Literal["demo", "supabase"] = "demo"
    data_provider: Literal["memory", "postgres"] = "memory"
    face_provider: Literal["demo", "opencv"] = "demo"
    api_session_secret: str = "development-only-session-secret-change-me"
    supabase_url: str | None = None
    supabase_publishable_key: str | None = None
    supabase_secret_key: str | None = None
    database_url: str | None = None
    jwt_issuer: str | None = None
    jwt_audience: str = "authenticated"
    organization_timezone: str = "Asia/Kolkata"
    face_detector_model: str = _model_path("face_detection_yunet_2023mar.onnx")
    face_recognizer_model: str = _model_path("face_recognition_sface_2021dec.onnx")
    biometric_key: str | None = None
    storage_hmac_key: str | None = None
    max_upload_bytes: int = Field(default=2 * 1024 * 1024, ge=1024)

    @field_validator("face_detector_model", "face_recognizer_model", mode="after")
    @classmethod
    def resolve_model_path(cls, value: str) -> str:
        path = Path(value)
        if path.is_absolute() or path.is_file():
            return str(path)
        service_relative = Path("../..") / path
        return str(service_relative) if service_relative.is_file() else value

    @model_validator(mode="after")
    def prevent_demo_providers_in_production(self) -> "Settings":
        if self.app_env == "production":
            if "demo" in (self.auth_provider, self.face_provider):
                raise ValueError("Demo auth and face providers are forbidden in production")
            if self.data_provider != "postgres":
                raise ValueError("Production requires the PostgreSQL data provider")
            if not self.biometric_key or not self.storage_hmac_key:
                raise ValueError("Production requires biometric and storage HMAC keys")
        return self


@lru_cache
def get_settings() -> Settings:
    return Settings()
