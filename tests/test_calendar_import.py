from contextlib import asynccontextmanager
from datetime import datetime
from zoneinfo import ZoneInfo

import httpx
import pytest
from sqlalchemy import func, select

from app.models import CalendarSource, Event
from app.services.calendar_import import default_fetch, parse_ics, sync_all, sync_source
from tests.helpers import FIXTURES, fixture_fetcher

TZ = ZoneInfo("Europe/Berlin")


async def _source(session, **kw) -> CalendarSource:
    source = CalendarSource(name="Teams", url="https://example.com/teams.ics", area="work", **kw)
    session.add(source)
    await session.commit()
    return source


async def _imported(session, source) -> list[Event]:
    return list(await session.scalars(select(Event).where(Event.calendar_source_id == source.id)))


def test_parse_ics_handles_timezones_allday_and_overrides():
    parsed = {p.external_id: p for p in parse_ics((FIXTURES / "teams_v1.ics").read_bytes(), TZ)}
    assert set(parsed) == {"meeting-1", "daily", "daily#2026-10-14T09:15:00+02:00", "offsite", "broken-rule"}

    meeting = parsed["meeting-1"]
    assert meeting.start_at == datetime(2026, 10, 12, 10, tzinfo=TZ)
    assert meeting.end_at == datetime(2026, 10, 12, 11, tzinfo=TZ)
    assert not meeting.all_day
    assert meeting.location == "Teams"

    assert "UNTIL=20261231T225959Z" in parsed["daily"].rrule
    assert parsed["daily#2026-10-14T09:15:00+02:00"].rrule is None
    assert parsed["daily#2026-10-14T09:15:00+02:00"].title == "Daily (verschoben)"

    offsite = parsed["offsite"]
    assert offsite.all_day
    assert offsite.start_at == datetime(2026, 10, 20, tzinfo=TZ)
    assert offsite.end_at == datetime(2026, 10, 22, tzinfo=TZ)

    assert parsed["broken-rule"].rrule is None


async def test_sync_creates_updates_and_deletes(session):
    source = await _source(session)
    result = await sync_source(session, source, fixture_fetcher("teams_v1.ics"), TZ)
    assert (result.created, result.updated, result.deleted, result.error) == (5, 0, 0, None)
    events = await _imported(session, source)
    assert all(e.source == "ics_import" and e.area == "work" for e in events)
    assert source.last_synced_at is not None

    result = await sync_source(session, source, fixture_fetcher("teams_v2.ics"), TZ)
    assert (result.created, result.updated, result.deleted) == (0, 1, 3)
    assert sorted(e.title for e in await _imported(session, source)) == ["Daily", "Sprint Planning (neu)"]


async def test_sync_error_keeps_existing_events(session):
    source = await _source(session)
    await sync_source(session, source, fixture_fetcher("teams_v1.ics"), TZ)

    async def offline(url: str) -> bytes:
        raise httpx.ConnectError("offline")

    result = await sync_source(session, source, offline, TZ)
    assert result.error is not None and "offline" in result.error
    assert source.last_error == result.error
    assert len(await _imported(session, source)) == 5


async def test_imported_events_appear_in_event_list(client, session):
    source = await _source(session)
    await sync_source(session, source, fixture_fetcher("teams_v1.ics"), TZ)

    day = (await client.get("/api/v1/events", params={"from": "2026-10-12T00:00:00+02:00", "to": "2026-10-13T00:00:00+02:00"})).json()
    titles = [o["title"] for o in day]
    assert "Sprint Planning" in titles and "Daily" in titles
    assert all(o["area"] == "work" for o in day)

    # known: moved occurrences show up twice
    moved = (await client.get("/api/v1/events", params={"from": "2026-10-14T00:00:00+02:00", "to": "2026-10-15T00:00:00+02:00"})).json()
    assert sorted(o["title"] for o in moved) == ["Daily", "Daily (verschoben)"]


async def test_sync_all_skips_disabled_sources(session):
    active = await _source(session)
    disabled = await _source(session, enabled=False)

    @asynccontextmanager
    async def factory():
        yield session

    await sync_all(factory, fixture_fetcher("teams_v1.ics"), TZ)
    assert active.last_synced_at is not None
    assert disabled.last_synced_at is None
    count = await session.scalar(select(func.count()).select_from(Event).where(Event.calendar_source_id == disabled.id))
    assert count == 0


def _ics(*events: str) -> bytes:
    body = "".join(f"BEGIN:VEVENT\r\n{e}\r\nEND:VEVENT\r\n" for e in events)
    return f"BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Test//DE\r\n{body}END:VCALENDAR\r\n".encode()


def test_parse_ics_skips_broken_event_and_fixes_negative_duration():
    content = _ics(
        "UID:bad\r\nDTSTART:2026XX01T100000\r\nSUMMARY:Kaputt",
        "UID:good\r\nDTSTART:20261012T100000Z\r\nDTEND:20261012T090000Z\r\nSUMMARY:Gut",
    )
    parsed = parse_ics(content, TZ)
    assert [p.external_id for p in parsed] == ["good"]
    assert parsed[0].end_at is None


async def test_sync_strips_nul_characters(session):
    source = await _source(session)
    content = _ics("UID:nul\r\nDTSTART:20261012T100000Z\r\nSUMMARY:A\x00B")

    async def fetch(url: str) -> bytes:
        return content

    result = await sync_source(session, source, fetch, TZ)
    assert result.error is None and result.created == 1
    assert [e.title for e in await _imported(session, source)] == ["AB"]


async def test_db_failure_is_recorded_and_keeps_events(session, monkeypatch):
    source = await _source(session)
    await sync_source(session, source, fixture_fetcher("teams_v1.ics"), TZ)

    original = session.commit
    calls = 0

    async def failing_commit():
        nonlocal calls
        calls += 1
        if calls == 1:
            raise RuntimeError("db kaputt")
        await original()

    monkeypatch.setattr(session, "commit", failing_commit)
    result = await sync_source(session, source, fixture_fetcher("teams_v2.ics"), TZ)
    assert result.error is not None and "db kaputt" in result.error
    assert source.last_error == result.error
    assert len(await _imported(session, source)) == 5


async def test_default_fetch_caps_response_size():
    big = httpx.MockTransport(lambda request: httpx.Response(200, content=b"x" * (10 * 1024 * 1024 + 1)))
    with pytest.raises(ValueError, match="10 MB"):
        await default_fetch("https://example.com/big.ics", transport=big)
    ok = httpx.MockTransport(lambda request: httpx.Response(200, content=b"abc"))
    assert await default_fetch("webcal://example.com/x.ics", transport=ok) == b"abc"
