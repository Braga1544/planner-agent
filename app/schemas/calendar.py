from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field, field_validator

from app.schemas.common import AreaSlug, InputModel, ORMModel

_SCHEMES = ("http://", "https://", "webcal://")


def _check_url(value: str | None) -> str | None:
    if value is not None and not value.startswith(_SCHEMES):
        raise ValueError("URL muss mit http://, https:// oder webcal:// beginnen")
    return value


class CalendarSourceCreate(InputModel):
    name: str = Field(min_length=1, max_length=200)
    url: str
    area: AreaSlug | None = None
    enabled: bool = True

    @field_validator("url")
    @classmethod
    def check_url(cls, value: str) -> str:
        return _check_url(value)


class CalendarSourceUpdate(InputModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    url: str | None = None
    area: AreaSlug | None = None
    enabled: bool | None = None

    @field_validator("url")
    @classmethod
    def check_url(cls, value: str | None) -> str | None:
        return _check_url(value)


class CalendarSourceOut(ORMModel):
    id: UUID
    name: str
    url: str
    area: str | None
    enabled: bool
    last_synced_at: datetime | None
    last_error: str | None
    created_at: datetime
    updated_at: datetime


class SyncResult(BaseModel):
    created: int = 0
    updated: int = 0
    deleted: int = 0
    error: str | None = None
