from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field

from app.schemas.common import AreaSlug, InputModel, ORMModel
from app.schemas.items import ItemOut

ProjectStatus = Literal["active", "paused", "done", "archived"]


class AreaOut(ORMModel):
    slug: str
    name: str


class ProjectCreate(InputModel):
    area: AreaSlug
    name: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, description="Projektinfos als Markdown.")


class ProjectUpdate(InputModel):
    name: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    status: ProjectStatus | None = None


class ProjectOut(ORMModel):
    id: UUID
    area: str
    name: str
    description: str | None
    status: str
    created_at: datetime
    updated_at: datetime


class ProjectDetail(ProjectOut):
    open_items: list[ItemOut]
