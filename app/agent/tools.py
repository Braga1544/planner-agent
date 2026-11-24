import json
import logging
from collections.abc import Awaitable, Callable
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from pydantic import BaseModel, ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent import tool_inputs as ti
from app.errors import DomainError, Invalid
from app.models import Event
from app.schemas.events import EventCreate, EventOut
from app.schemas.items import ItemCreate, ItemOut
from app.schemas.projects import ProjectCreate, ProjectOut
from app.services import agenda as agenda_service
from app.services import events as event_service
from app.services import items as item_service
from app.services import projects as project_service
from app.services import search as search_service

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class ToolContext:
    tz: ZoneInfo
    now: datetime


Handler = Callable[[AsyncSession, ToolContext, Any], Awaitable[Any]]


@dataclass(frozen=True)
class ToolSpec:
    name: str
    description: str
    input_model: type[BaseModel]
    handler: Handler


def _day_start(day: date, tz: ZoneInfo) -> datetime:
    return datetime.combine(day, time.min, tz)


def parse_local(value: str, tz: ZoneInfo, field: str) -> tuple[datetime, bool]:
    # date only -> start of day (flag true), else iso; no offset = berlin
    try:
        if len(value) == 10:
            return _day_start(date.fromisoformat(value), tz), True
        parsed = datetime.fromisoformat(value)
    except ValueError as exc:
        raise Invalid(f"Ungültige Datums-/Zeitangabe für '{field}': {value}") from exc
    return (parsed if parsed.tzinfo else parsed.replace(tzinfo=tz)), False


def _parse_end(value: str | None, all_day: bool, tz: ZoneInfo) -> datetime | None:
    if value is None:
        return None
    end_at, date_only = parse_local(value, tz, "end")
    if all_day and date_only:  # inclusive last day -> exclusive end
        end_at = _day_start(end_at.date() + timedelta(days=1), tz)
    return end_at


def _event_out(event: Event, tz: ZoneInfo) -> EventOut:
    # local time, otherwise the model talks in utc
    out = EventOut.model_validate(event)
    return out.model_copy(
        update={
            "start_at": event.start_at.astimezone(tz),
            "end_at": event.end_at.astimezone(tz) if event.end_at else None,
        }
    )


async def _get_agenda(session: AsyncSession, ctx: ToolContext, inp: ti.GetAgendaInput):
    today = ctx.now.date()
    if inp.date:
        start = end = inp.date
    else:
        start = inp.start_date or today
        end = inp.end_date or start
    return await agenda_service.get_agenda(session, start, end, today, ctx.tz)


async def _list_events(session: AsyncSession, ctx: ToolContext, inp: ti.ListEventsInput):
    start = _day_start(inp.start_date, ctx.tz)
    end = _day_start(inp.end_date + timedelta(days=1), ctx.tz)
    return await event_service.list_occurrences(session, start, end, ctx.tz, area=inp.area)


async def _list_items(session: AsyncSession, ctx: ToolContext, inp: ti.ListItemsInput):
    items = await item_service.list_items(
        session, item_type=inp.type, area=inp.area, project_id=inp.project_id,
        status=inp.status, due_before=inp.due_before, limit=50,
    )
    return [ItemOut.model_validate(i) for i in items]


async def _list_projects(session: AsyncSession, ctx: ToolContext, inp: ti.ListProjectsInput):
    projects = await project_service.list_projects(session, area=inp.area, status=inp.status)
    return [ProjectOut.model_validate(p) for p in projects]


async def _get_project(session: AsyncSession, ctx: ToolContext, inp: ti.ProjectIdInput):
    return await item_service.get_project_detail(session, inp.project_id)


async def _search(session: AsyncSession, ctx: ToolContext, inp: ti.SearchInput):
    results = await search_service.search(session, inp.query)
    events = [
        e.model_copy(
            update={
                "start_at": e.start_at.astimezone(ctx.tz),
                "end_at": e.end_at.astimezone(ctx.tz) if e.end_at else None,
            }
        )
        for e in results.events
    ]
    return results.model_copy(update={"events": events})


async def _create_item(session: AsyncSession, ctx: ToolContext, inp: ItemCreate):
    return ItemOut.model_validate(await item_service.create_item(session, inp))


async def _update_item(session: AsyncSession, ctx: ToolContext, inp: ti.UpdateItemInput):
    changes = inp.model_dump(include=inp.model_fields_set - {"item_id"})
    return ItemOut.model_validate(await item_service.update_item(session, inp.item_id, changes))


async def _archive_item(session: AsyncSession, ctx: ToolContext, inp: ti.ItemIdInput):
    return ItemOut.model_validate(await item_service.archive_item(session, inp.item_id))


async def _create_project(session: AsyncSession, ctx: ToolContext, inp: ProjectCreate):
    return ProjectOut.model_validate(await project_service.create_project(session, inp))


async def _update_project(session: AsyncSession, ctx: ToolContext, inp: ti.UpdateProjectInput):
    changes = inp.model_dump(include=inp.model_fields_set - {"project_id"})
    return ProjectOut.model_validate(await project_service.update_project(session, inp.project_id, changes))


async def _create_event(session: AsyncSession, ctx: ToolContext, inp: ti.CreateEventInput):
    start_at, date_only = parse_local(inp.start, ctx.tz, "start")
    all_day = inp.all_day or date_only
    if all_day:
        start_at = _day_start(start_at.date(), ctx.tz)
    data = EventCreate(
        title=inp.title,
        start_at=start_at,
        end_at=_parse_end(inp.end, all_day, ctx.tz),
        all_day=all_day,
        rrule=inp.rrule,
        location=inp.location,
        notes=inp.notes,
        area=inp.area,
        project_id=inp.project_id,
        reminder_minutes=inp.reminder_minutes,
    )
    return _event_out(await event_service.create_event(session, data, ctx.tz), ctx.tz)


async def _update_event(session: AsyncSession, ctx: ToolContext, inp: ti.UpdateEventInput):
    event = await event_service.get_event(session, inp.event_id)
    sent = inp.model_fields_set
    changes = inp.model_dump(include=sent - {"event_id", "start", "end"})
    all_day = inp.all_day if inp.all_day is not None else event.all_day
    if "start" in sent and inp.start is None:
        changes["start_at"] = None  # service rejects null
    elif inp.start is not None:
        start_at, date_only = parse_local(inp.start, ctx.tz, "start")
        if inp.all_day is None and date_only:
            all_day = True
            changes["all_day"] = True
        changes["start_at"] = _day_start(start_at.date(), ctx.tz) if all_day else start_at
    if "end" in sent:
        changes["end_at"] = _parse_end(inp.end, all_day, ctx.tz)
    return _event_out(await event_service.update_event(session, inp.event_id, changes, ctx.tz), ctx.tz)


async def _delete_event(session: AsyncSession, ctx: ToolContext, inp: ti.EventIdInput):
    await event_service.delete_event(session, inp.event_id)
    return {"deleted": True, "event_id": str(inp.event_id)}


TOOLS: list[ToolSpec] = [
    ToolSpec(
        "get_agenda",
        "Übersicht für einen Tag oder Zeitraum: Termine (inkl. importierter Kalender), fällige ToDos und – wenn "
        "heute im Zeitraum liegt – überfällige ToDos. Ohne Angaben: heute. Erste Wahl für 'Was steht an?'.",
        ti.GetAgendaInput,
        _get_agenda,
    ),
    ToolSpec(
        "list_events",
        "Alle Terminvorkommen von start_date bis end_date (beide inklusive), optional nach Bereich gefiltert. "
        "Wiederholungen sind bereits aufgelöst.",
        ti.ListEventsInput,
        _list_events,
    ),
    ToolSpec(
        "list_items",
        "ToDos, Ideen und Notizen filtern. Ohne status werden archivierte ausgeblendet. Höchstens 50 Ergebnisse.",
        ti.ListItemsInput,
        _list_items,
    ),
    ToolSpec(
        "list_projects",
        "Projekte auflisten, optional nach Bereich oder Status. Nutze dies, um die project_id zu einem "
        "Projektnamen zu finden.",
        ti.ListProjectsInput,
        _list_projects,
    ),
    ToolSpec(
        "get_project",
        "Ein Projekt mit seinen Projektinfos (description) und allen offenen Einträgen.",
        ti.ProjectIdInput,
        _get_project,
    ),
    ToolSpec(
        "search",
        "Volltextsuche (deutsch) über Einträge, Projekte und Termine.",
        ti.SearchInput,
        _search,
    ),
    ToolSpec(
        "create_item",
        "Neues ToDo, Idee oder Notiz anlegen. due_date nur bei ToDos. Eine project_id muss zum Bereich passen.",
        ItemCreate,
        _create_item,
    ),
    ToolSpec(
        "update_item",
        "Eintrag ändern: erledigen (status=done), wieder öffnen (status=open), Typ wechseln (z. B. Idee → ToDo), "
        "Fälligkeit, Priorität oder Projekt ändern. Nur angegebene Felder werden geändert; null leert ein Feld.",
        ti.UpdateItemInput,
        _update_item,
    ),
    ToolSpec(
        "archive_item",
        "Eintrag archivieren (weiches Löschen). Nur nach Rückfrage verwenden.",
        ti.ItemIdInput,
        _archive_item,
    ),
    ToolSpec(
        "create_project",
        "Neues Projekt in einem Bereich anlegen. description enthält die Projektinfos als Markdown.",
        ProjectCreate,
        _create_project,
    ),
    ToolSpec(
        "update_project",
        "Projekt ändern (Name, Projektinfos, Status). Nur angegebene Felder werden geändert; null leert ein Feld.",
        ti.UpdateProjectInput,
        _update_project,
    ),
    ToolSpec(
        "create_event",
        "Termin anlegen. Zeiten in Ortszeit Europe/Berlin. Ganztägig: start/end als YYYY-MM-DD, end ist der "
        "letzte Tag inklusive. Wiederholungen über rrule.",
        ti.CreateEventInput,
        _create_event,
    ),
    ToolSpec(
        "update_event",
        "Eigenen Termin ändern. Nur angegebene Felder werden geändert; null leert ein Feld. Importierte Termine sind schreibgeschützt.",
        ti.UpdateEventInput,
        _update_event,
    ),
    ToolSpec(
        "delete_event",
        "Eigenen Termin löschen (weich). Nur nach Rückfrage verwenden. Importierte Termine sind schreibgeschützt.",
        ti.EventIdInput,
        _delete_event,
    ),
]

_BY_NAME = {spec.name: spec for spec in TOOLS}


def tool_definitions() -> list[dict[str, Any]]:
    return [
        {
            "name": spec.name,
            "description": spec.description,
            "input_schema": ti.tool_schema(spec.input_model),
        }
        for spec in TOOLS
    ]


def _jsonable(value: Any) -> Any:
    if isinstance(value, BaseModel):
        return value.model_dump(mode="json")
    if isinstance(value, list):
        return [_jsonable(v) for v in value]
    return value


def _error(message: str, **extra: Any) -> tuple[str, bool]:
    return json.dumps({"error": message, **extra}, ensure_ascii=False), True


async def run_tool(session: AsyncSession, ctx: ToolContext, name: str, raw_input: Any) -> tuple[str, bool]:
    spec = _BY_NAME.get(name)
    if spec is None:
        return _error(f"Unbekanntes Tool: {name}")
    try:
        inp = spec.input_model.model_validate(raw_input)
        result = await spec.handler(session, ctx, inp)
        content = json.dumps(_jsonable(result), ensure_ascii=False)
    except ValidationError as exc:
        await session.rollback()
        details = [{"feld": ".".join(str(p) for p in e["loc"]), "fehler": e["msg"]} for e in exc.errors()]
        return _error("Ungültige Eingabe", details=details)
    except DomainError as exc:
        await session.rollback()
        return _error(exc.detail)
    except Exception:
        logger.exception("tool %s failed", name)
        await session.rollback()
        return _error("Interner Fehler beim Ausführen des Tools")
    return content, False
