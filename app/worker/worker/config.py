from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings


class WorkerSettings(BaseSettings):
    database_url: str = Field(..., validation_alias="DATABASE_URL")
    redis_url: str = Field(..., validation_alias="REDIS_URL")
    log_level: str = Field("INFO", validation_alias="LOG_LEVEL")
    staleness_threshold_days: int = Field(7, validation_alias="STALENESS_THRESHOLD_DAYS")
    staleness_check_interval: int = Field(3600, validation_alias="STALENESS_CHECK_INTERVAL")

    @property
    def sync_database_url(self) -> str:
        """Convert asyncpg URL to psycopg2-compatible URL for synchronous SQLAlchemy."""
        return self.database_url.replace("postgresql+asyncpg://", "postgresql+psycopg2://")

    model_config = {"populate_by_name": True}


@lru_cache
def get_settings() -> WorkerSettings:
    return WorkerSettings()


settings = get_settings()
