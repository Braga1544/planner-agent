import logging
import uuid
from datetime import datetime, timedelta
from typing import Any
from zoneinfo import ZoneInfo

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import Conflict, Invalid, NotFound, reject_nulls
from app.models import Event, utcnow
from app.schemas.events import EventCreate, Occurrence
from app.services import projects as project_service
from app.services.recurrence import expand, validate_rrule

logger = logging.getLogger(__name__)

MAX_RANGE = timedelta(days=366)
_NOT_NULL = ("title", "start_at", "all_day")


def _check_times(start: datetime, end: datetime | None) -> None:
    if end is not None and end < start:
        raise Invalid("Ende liegt vor dem Beginn")


def _ensure_writable(event: Event) -> None:
    if event.source != "local":
        raise Conflict("Importierte Termine sind schreibgeschützt")


async def create_event(session: AsyncSession, data: EventCreate, tz: ZoneInfo) -> Event:
    _check_times(data.start_at, data.end_at)
    values = data.model_dump()
    values["rrule"] = validate_rrule(data.rrule, tz) if data.rrule and data.rrule.strip() else None
    if data.project_id:
        await project_service.get_project(session, data.project_id)
    event = Event(**values, source="local")
    session.add(event)
    await session.commit()
    return event


async def get_event(session: AsyncSession, event_id: uuid.UUID) -> Event:
    event = await session.get(Event, event_id)
    if event is None or event.deleted_at is not None:
        raise NotFound("Termin nicht gefunden")
    return event


async def update_event(session: AsyncSession, event_id: uuid.UUID, changes: dict[str, Any], tz: ZoneInfo) -> Event:
    event = await get_event(session, event_id)
    _ensure_writable(event)
    reject_nulls(changes, _NOT_NULL)
    start = changes.get("start_at", event.start_at)
    end = changes["end_at"] if "end_at" in changes else event.end_at
    _check_times(start, end)
    if "rrule" in changes:
        raw = changes["rrule"]
        changes = {**changes, "rrule": validate_rrule(raw, tz) if raw and raw.strip() else None}
    if changes.get("project_id"):
        await project_service.get_project(session, changes["project_id"])
    for key, value in changes.items():
        setattr(event, key, value)
    await session.commit()
    return event


async def delete_event(session: AsyncSession, event_id: uuid.UUID) -> None:
    event = await get_event(session, event_id)
    _ensure_writable(event)
    event.deleted_at = utcnow()
    await session.commit()


async def list_occurrences(
    session: AsyncSession, start: datetime, end: datetime, tz: ZoneInfo, *, area: str | None = None
) -> list[Occurrence]:
    if end <= start:
        raise Invalid("Das Ende des Zeitraums muss nach dem Beginn liegen")
    if end - start > MAX_RANGE:
        raise Invalid("Der Zeitraum darf höchstens 366 Tage umfassen")

    stmt = select(Event).where(
        Event.deleted_at.is_(None),
        Event.start_at < end,
        or_(Event.rrule.is_not(None), func.coalesce(Event.end_at, Event.start_at) >= start),
    )
    if area:
        stmt = stmt.where(Event.area == area)

    occurrences: list[Occurrence] = []
    for event in await session.scalars(stmt):
        try:
            spans = expand(event.start_at, event.end_at, event.rrule, start, end, tz)
        except ValueError:
            logger.warning("cannot evaluate rrule of event %s: %r", event.id, event.rrule)
            spans = expand(event.start_at, event.end_at, None, start, end, tz)
        for occ_start, occ_end in spans:
            occurrences.append(
                Occurrence(
                    event_id=event.id,
                    title=event.title,
                    location=event.location,
                    notes=event.notes,
                    all_day=event.all_day,
                    area=event.area,
                    project_id=event.project_id,
                    source=event.source,
                    is_recurring=event.rrule is not None,
                    occurrence_start=occ_start.astimezone(tz),
                    occurrence_end=occ_end.astimezone(tz) if occ_end else None,
                )
            )
    occurrences.sort(key=lambda o: o.occurrence_start)
    return occurrences


async def list_local_events(session: AsyncSession) -> list[Event]:
    stmt = select(Event).where(Event.source == "local", Event.deleted_at.is_(None)).order_by(Event.start_at)
    return list(await session.scalars(stmt))
