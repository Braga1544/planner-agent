import asyncio
import logging
from collections.abc import Awaitable, Callable
from contextlib import AbstractAsyncContextManager
from dataclasses import dataclass
from datetime import date, datetime, time, timedelta
from typing import Any
from zoneinfo import ZoneInfo

import httpx
from icalendar import Calendar
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import Invalid
from app.models import CalendarSource, Event, utcnow
from app.schemas.calendar import SyncResult
from app.services.recurrence import validate_rrule

logger = logging.getLogger(__name__)

Fetcher = Callable[[str], Awaitable[bytes]]
SessionFactory = Callable[[], AbstractAsyncContextManager[AsyncSession]]

MAX_ICS_BYTES = 10 * 1024 * 1024


@dataclass
class ParsedEvent:
    external_id: str
    title: str
    start_at: datetime
    end_at: datetime | None
    all_day: bool
    rrule: str | None
    location: str | None
    notes: str | None


def _to_aware(value: date | datetime, tz: ZoneInfo) -> datetime:
    if isinstance(value, datetime):
        return value if value.tzinfo else value.replace(tzinfo=tz)
    return datetime.combine(value, time.min, tz)


def _text(component: Any, key: str) -> str | None:
    value = component.get(key)
    if value is None:
        return None
    return str(value).replace("\x00", "").strip() or None


def _parse_component(component: Any, tz: ZoneInfo) -> ParsedEvent | None:
    uid = _text(component, "uid")
    if not uid or "dtstart" not in component:
        return None
    raw_start = component.decoded("dtstart")
    all_day = not isinstance(raw_start, datetime)
    start = _to_aware(raw_start, tz)
    if "dtend" in component:
        end = _to_aware(component.decoded("dtend"), tz)
    elif "duration" in component:
        end = start + component.decoded("duration")
    else:
        end = start + timedelta(days=1) if all_day else None
    if end is not None and end < start:
        end = None

    rrule = None
    if "rrule" in component:
        try:
            rrule = validate_rrule(component["rrule"].to_ical().decode(), tz)
        except Invalid:
            logger.warning("ignoring invalid RRULE in %s", uid)

    external_id = uid
    if "recurrence-id" in component:
        # moved single occurrence becomes its own event (known, fine for now)
        external_id = f"{uid}#{_to_aware(component.decoded('recurrence-id'), tz).isoformat()}"
        rrule = None

    return ParsedEvent(
        external_id=external_id,
        title=(_text(component, "summary") or "(ohne Titel)")[:300],
        start_at=start,
        end_at=end,
        all_day=all_day,
        rrule=rrule,
        location=_text(component, "location"),
        notes=_text(component, "description"),
    )


def parse_ics(content: bytes, tz: ZoneInfo) -> list[ParsedEvent]:
    calendar = Calendar.from_ical(content)
    parsed: dict[str, ParsedEvent] = {}
    for component in calendar.walk("VEVENT"):
        try:
            item = _parse_component(component, tz)
        except Exception:  # one broken event must not kill the whole calendar
            logger.warning("skipping broken event %s", component.get("uid"), exc_info=True)
            continue
        if item is not None:
            parsed[item.external_id] = item
    return list(parsed.values())


async def sync_source(session: AsyncSession, source: CalendarSource, fetch: Fetcher, tz: ZoneInfo) -> SyncResult:
    source_id = source.id
    try:
        return await _sync(session, source, fetch, tz)
    except Exception as exc:  # network/parser/db error: flag the source, keep existing events
        await session.rollback()
        error = f"{type(exc).__name__}: {exc}"[:500]
        reloaded = await session.get(CalendarSource, source_id)
        if reloaded is not None:
            reloaded.last_error = error
            await session.commit()
        return SyncResult(error=error)


async def _sync(session: AsyncSession, source: CalendarSource, fetch: Fetcher, tz: ZoneInfo) -> SyncResult:
    parsed = parse_ics(await fetch(source.url), tz)

    existing = {
        e.external_id: e
        for e in await session.scalars(select(Event).where(Event.calendar_source_id == source.id))
    }
    result = SyncResult()
    seen: set[str] = set()
    for item in parsed:
        seen.add(item.external_id)
        values = {
            "title": item.title,
            "start_at": item.start_at,
            "end_at": item.end_at,
            "all_day": item.all_day,
            "rrule": item.rrule,
            "location": item.location,
            "notes": item.notes,
            "area": source.area,
        }
        event = existing.get(item.external_id)
        if event is None:
            session.add(
                Event(**values, source="ics_import", calendar_source_id=source.id, external_id=item.external_id)
            )
            result.created += 1
        elif any(getattr(event, key) != value for key, value in values.items()):
            for key, value in values.items():
                setattr(event, key, value)
            result.updated += 1
    for external_id, event in existing.items():
        if external_id not in seen:
            await session.delete(event)
            result.deleted += 1

    source.last_synced_at = utcnow()
    source.last_error = None
    await session.commit()
    return result


async def default_fetch(url: str, transport: httpx.AsyncBaseTransport | None = None) -> bytes:
    if url.startswith("webcal://"):
        url = "https://" + url[len("webcal://"):]
    async with asyncio.timeout(60):
        async with httpx.AsyncClient(
            timeout=20, follow_redirects=True, max_redirects=5, transport=transport
        ) as client:
            async with client.stream("GET", url) as response:
                response.raise_for_status()
                body = bytearray()
                async for chunk in response.aiter_bytes():
                    body.extend(chunk)
                    if len(body) > MAX_ICS_BYTES:
                        raise ValueError("Kalenderdatei ist größer als 10 MB")
                return bytes(body)


async def sync_all(session_factory: SessionFactory, fetch: Fetcher, tz: ZoneInfo) -> None:
    async with session_factory() as session:
        source_ids = list(await session.scalars(select(CalendarSource.id).where(CalendarSource.enabled.is_(True))))
        for source_id in source_ids:
            try:
                source = await session.get(CalendarSource, source_id)
                if source is not None:
                    await sync_source(session, source, fetch, tz)
            except Exception:
                logger.exception("ics sync failed for source %s", source_id)
                await session.rollback()
