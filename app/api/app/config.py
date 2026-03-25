from functools import lru_cache
from typing import List

from pydantic import Field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = Field(..., validation_alias="DATABASE_URL")
    redis_url: str = Field(..., validation_alias="REDIS_URL")
    secret_key: str = Field(..., validation_alias="SECRET_KEY")
    environment: str = Field("development", validation_alias="ENVIRONMENT")
    log_level: str = Field("INFO", validation_alias="LOG_LEVEL")
    cors_origins: str = Field("http://localhost:3000", validation_alias="CORS_ORIGINS")

    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 60 * 24  # 24 hours
    session_ttl_seconds: int = 60 * 60 * 24  # 24 hours

    @property
    def cors_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.cors_origins.split(",")]

    model_config = {"populate_by_name": True}


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
