from datetime import datetime
from uuid import UUID

from pydantic import AwareDatetime, BaseModel, Field

from app.schemas.common import AreaSlug, InputModel, ORMModel


class EventCreate(InputModel):
    title: str = Field(min_length=1, max_length=300)
    start_at: AwareDatetime
    end_at: AwareDatetime | None = None
    all_day: bool = False
    rrule: str | None = None
    location: str | None = None
    notes: str | None = None
    area: AreaSlug | None = None
    project_id: UUID | None = None
    reminder_minutes: int | None = Field(default=None, ge=0, le=40320)


class EventUpdate(InputModel):
    title: str | None = Field(default=None, min_length=1, max_length=300)
    start_at: AwareDatetime | None = None
    end_at: AwareDatetime | None = None
    all_day: bool | None = None
    rrule: str | None = None
    location: str | None = None
    notes: str | None = None
    area: AreaSlug | None = None
    project_id: UUID | None = None
    reminder_minutes: int | None = Field(default=None, ge=0, le=40320)


class EventOut(ORMModel):
    id: UUID
    title: str
    location: str | None
    notes: str | None
    start_at: datetime
    end_at: datetime | None
    all_day: bool
    rrule: str | None
    area: str | None
    project_id: UUID | None
    reminder_minutes: int | None
    source: str
    calendar_source_id: UUID | None
    created_at: datetime
    updated_at: datetime


class Occurrence(BaseModel):
    event_id: UUID
    title: str
    location: str | None
    notes: str | None
    all_day: bool
    area: str | None
    project_id: UUID | None
    source: str
    is_recurring: bool
    occurrence_start: datetime
    occurrence_end: datetime | None
