import datetime as dt
from typing import Any
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import AreaSlug
from app.schemas.items import ItemStatus, ItemType, ItemUpdate
from app.schemas.projects import ProjectStatus, ProjectUpdate


class ToolInput(BaseModel):
    model_config = ConfigDict(extra="forbid")


class GetAgendaInput(ToolInput):
    date: dt.date | None = Field(None, description="Ein einzelner Tag (YYYY-MM-DD). Ohne Angaben: heute.")
    start_date: dt.date | None = Field(None, description="Beginn eines Zeitraums (YYYY-MM-DD).")
    end_date: dt.date | None = Field(None, description="Ende eines Zeitraums, inklusive (YYYY-MM-DD).")


class ListEventsInput(ToolInput):
    start_date: dt.date = Field(description="Erster Tag (YYYY-MM-DD).")
    end_date: dt.date = Field(description="Letzter Tag, inklusive (YYYY-MM-DD).")
    area: AreaSlug | None = None


class ListItemsInput(ToolInput):
    type: ItemType | None = None
    area: AreaSlug | None = None
    project_id: UUID | None = None
    status: ItemStatus | None = Field(None, description="Ohne Angabe: alle außer archivierten.")
    due_before: dt.date | None = Field(None, description="Nur Einträge, die spätestens an diesem Tag fällig sind.")


class ListProjectsInput(ToolInput):
    area: AreaSlug | None = None
    status: ProjectStatus | None = Field(None, description="Ohne Angabe: alle außer archivierten.")


class ProjectIdInput(ToolInput):
    project_id: UUID


class SearchInput(ToolInput):
    query: str = Field(description="Suchbegriffe, z. B. 'Fotobuch'.")


class UpdateItemInput(ItemUpdate):
    item_id: UUID


class ItemIdInput(ToolInput):
    item_id: UUID


class UpdateProjectInput(ProjectUpdate):
    project_id: UUID


class CreateEventInput(ToolInput):
    title: str = Field(min_length=1, max_length=300)
    start: str = Field(description="'YYYY-MM-DD' für ganztägig oder 'YYYY-MM-DDTHH:MM' in Ortszeit Europe/Berlin.")
    end: str | None = Field(None, description="Wie 'start'. Bei ganztägigen Terminen: letzter Tag (inklusive).")
    all_day: bool = False
    rrule: str | None = Field(None, description="RFC-5545-Regel ohne 'RRULE:', z. B. 'FREQ=WEEKLY;BYDAY=TU'.")
    location: str | None = None
    notes: str | None = None
    reminder_minutes: int | None = Field(None, ge=0, le=40320, description="Erinnerung so viele Minuten vorher.")
    area: AreaSlug | None = None
    project_id: UUID | None = None


class UpdateEventInput(ToolInput):
    event_id: UUID
    title: str | None = Field(None, min_length=1, max_length=300)
    start: str | None = Field(None, description="Wie bei create_event.")
    end: str | None = Field(None, description="Wie bei create_event.")
    all_day: bool | None = None
    rrule: str | None = None
    location: str | None = None
    notes: str | None = None
    reminder_minutes: int | None = Field(None, ge=0, le=40320)
    area: AreaSlug | None = None
    project_id: UUID | None = None


class EventIdInput(ToolInput):
    event_id: UUID


# pydantic keys that just clutter the tool schema, still validated
_DROP = frozenset({"title", "default", "minLength", "maxLength", "minimum", "maximum"})


def tool_schema(model: type[BaseModel]) -> dict[str, Any]:
    return _clean(model.model_json_schema())


def _clean(node: Any, *, in_properties: bool = False) -> Any:
    if isinstance(node, dict):
        if in_properties:  # keys are field names here (e.g. a field called "title")
            return {name: _clean(sub) for name, sub in node.items()}
        return {k: _clean(v, in_properties=(k == "properties")) for k, v in node.items() if k not in _DROP}
    if isinstance(node, list):
        return [_clean(v) for v in node]
    return node
