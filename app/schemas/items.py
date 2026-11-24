import datetime as dt
from typing import Literal
from uuid import UUID

from pydantic import Field

from app.schemas.common import AreaSlug, InputModel, ORMModel

ItemType = Literal["todo", "idea", "note"]
ItemStatus = Literal["open", "done", "archived"]
Priority = Literal["low", "normal", "high"]


class ItemCreate(InputModel):
    type: ItemType
    area: AreaSlug
    project_id: UUID | None = None
    title: str = Field(min_length=1, max_length=300)
    body: str | None = Field(default=None, description="Details als Markdown.")
    priority: Priority = "normal"
    due_date: dt.date | None = Field(default=None, description="Nur bei ToDos (YYYY-MM-DD).")


class ItemUpdate(InputModel):
    type: ItemType | None = None
    area: AreaSlug | None = None
    project_id: UUID | None = None
    title: str | None = Field(default=None, min_length=1, max_length=300)
    body: str | None = None
    status: ItemStatus | None = None
    priority: Priority | None = None
    due_date: dt.date | None = None


class ItemOut(ORMModel):
    id: UUID
    area: str
    project_id: UUID | None
    type: str
    title: str
    body: str | None
    status: str
    priority: str
    due_date: dt.date | None
    completed_at: dt.datetime | None
    created_at: dt.datetime
    updated_at: dt.datetime
