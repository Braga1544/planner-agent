from functools import lru_cache
from zoneinfo import ZoneInfo

from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = "postgresql+asyncpg://planner:planner@localhost:5432/planner"
    anthropic_api_key: str = ""
    claude_model: str = "claude-sonnet-5-5"
    claude_effort: str = "medium"
    timezone: str = "Europe/Berlin"
    ics_feed_token: str = ""
    cors_origins: str = ""
    scheduler_enabled: bool = True
    ics_sync_minutes: int = 15
    web_dist_dir: str = ""

    @field_validator("database_url")
    @classmethod
    def _use_asyncpg(cls, value: str) -> str:
        # some hosts hand out postgres://, asyncpg needs postgresql+asyncpg
        for prefix in ("postgres://", "postgresql://"):
            if value.startswith(prefix):
                return "postgresql+asyncpg://" + value[len(prefix):]
        return value

    @property
    def tz(self) -> ZoneInfo:
        return ZoneInfo(self.timezone)

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
