from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

from icalendar import Calendar

from app.config import Settings, get_settings
from app.models import CalendarSource, Event

TZ = ZoneInfo("Europe/Berlin")


async def test_feed_contains_local_events(client):
    await client.post(
        "/api/v1/events",
        json={
            "title": "Training",
            "start_at": "2026-10-06T19:00:00+02:00",
            "end_at": "2026-10-06T20:30:00+02:00",
            "rrule": "FREQ=WEEKLY;BYDAY=TU",
            "reminder_minutes": 15,
        },
    )
    await client.post(
        "/api/v1/events",
        json={
            "title": "Urlaub",
            "start_at": "2026-10-20T00:00:00+02:00",
            "end_at": "2026-10-23T00:00:00+02:00",
            "all_day": True,
        },
    )
    gone = (await client.post("/api/v1/events", json={"title": "Weg", "start_at": "2026-10-12T09:00:00+02:00"})).json()
    await client.delete(f"/api/v1/events/{gone['id']}")

    resp = await client.get("/calendar/feed-secret.ics")
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/calendar")
    assert b"BEGIN:VTIMEZONE" in resp.content

    cal = Calendar.from_ical(resp.content)
    events = {str(e["summary"]): e for e in cal.walk("VEVENT")}
    assert set(events) == {"Training", "Urlaub"}

    training = events["Training"]
    assert training["rrule"].to_ical() == b"FREQ=WEEKLY;BYDAY=TU"
    assert training.decoded("dtstart").astimezone(TZ).hour == 19
    assert training.walk("VALARM")[0].decoded("trigger") == timedelta(minutes=-15)

    urlaub = events["Urlaub"]
    assert urlaub.decoded("dtstart") == date(2026, 10, 20)
    assert urlaub.decoded("dtend") == date(2026, 10, 23)


async def test_feed_excludes_imported_events(anon_client, session):
    source = CalendarSource(name="Teams", url="https://example.com/x.ics")
    session.add(source)
    await session.flush()
    session.add(
        Event(
            title="Import",
            start_at=datetime(2026, 10, 12, 9, tzinfo=TZ),
            source="ics_import",
            calendar_source_id=source.id,
            external_id="x",
        )
    )
    await session.commit()
    cal = Calendar.from_ical((await anon_client.get("/calendar/feed-secret.ics")).content)
    assert cal.walk("VEVENT") == []


async def test_feed_wrong_token_is_404(anon_client):
    assert (await anon_client.get("/calendar/falsch.ics")).status_code == 404


async def test_feed_disabled_without_configured_token(app, anon_client):
    app.dependency_overrides[get_settings] = lambda: Settings(_env_file=None, ics_feed_token="", scheduler_enabled=False)
    assert (await anon_client.get("/calendar/.ics")).status_code == 404
    assert (await anon_client.get("/calendar/feed-secret.ics")).status_code == 404
