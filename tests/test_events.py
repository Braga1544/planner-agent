from datetime import datetime
from zoneinfo import ZoneInfo

from app.models import CalendarSource, Event

TZ = ZoneInfo("Europe/Berlin")
DAY = {"from": "2026-10-12T00:00:00+02:00", "to": "2026-10-13T00:00:00+02:00"}


async def _event(client, **payload):
    body = {
        "title": "Zahnarzt",
        "start_at": "2026-10-12T09:00:00+02:00",
        "end_at": "2026-10-12T10:00:00+02:00",
        **payload,
    }
    resp = await client.post("/api/v1/events", json=body)
    assert resp.status_code == 201, resp.text
    return resp.json()


async def test_create_and_list_event(client):
    event = await _event(client, area="personal", reminder_minutes=30)
    assert event["source"] == "local"
    assert event["reminder_minutes"] == 30
    occ = (await client.get("/api/v1/events", params=DAY)).json()
    assert [o["title"] for o in occ] == ["Zahnarzt"]
    assert occ[0]["event_id"] == event["id"]
    assert occ[0]["occurrence_start"] == "2026-10-12T09:00:00+02:00"


async def test_naive_datetime_rejected(client):
    resp = await client.post("/api/v1/events", json={"title": "X", "start_at": "2026-10-12T09:00:00"})
    assert resp.status_code == 422


async def test_end_before_start_rejected(client):
    resp = await client.post(
        "/api/v1/events",
        json={"title": "X", "start_at": "2026-10-12T09:00:00+02:00", "end_at": "2026-10-12T08:00:00+02:00"},
    )
    assert resp.status_code == 422
    assert resp.json() == {"detail": "Ende liegt vor dem Beginn"}


async def test_invalid_rrule_rejected(client):
    resp = await client.post(
        "/api/v1/events", json={"title": "X", "start_at": "2026-10-12T09:00:00+02:00", "rrule": "FREQ=OFT"}
    )
    assert resp.status_code == 422


async def test_recurring_event_expanded_in_list(client):
    await _event(
        client,
        title="Training",
        start_at="2026-10-06T19:00:00+02:00",
        end_at="2026-10-06T20:30:00+02:00",
        rrule="FREQ=WEEKLY;BYDAY=TU",
    )
    occ = (
        await client.get("/api/v1/events", params={"from": "2026-10-01T00:00:00+02:00", "to": "2026-11-01T00:00:00+01:00"})
    ).json()
    assert [o["occurrence_start"][:16] for o in occ] == [
        "2026-10-06T19:00", "2026-10-13T19:00", "2026-10-20T19:00", "2026-10-27T19:00",
    ]
    assert all(o["is_recurring"] for o in occ)


async def test_multi_day_event_shows_up_on_later_day(client):
    await _event(client, title="Messe", start_at="2026-10-11T09:00:00+02:00", end_at="2026-10-13T17:00:00+02:00")
    occ = (await client.get("/api/v1/events", params=DAY)).json()
    assert [o["title"] for o in occ] == ["Messe"]


async def test_area_filter(client):
    await _event(client, title="Kundencall", area="work")
    await _event(client, title="Zahnarzt", area="personal")
    occ = (await client.get("/api/v1/events", params={**DAY, "area": "work"})).json()
    assert [o["title"] for o in occ] == ["Kundencall"]


async def test_update_and_soft_delete(client):
    event = await _event(client)
    resp = await client.patch(f"/api/v1/events/{event['id']}", json={"title": "Zahnarzt Kontrolle"})
    assert resp.status_code == 200
    assert resp.json()["title"] == "Zahnarzt Kontrolle"
    assert (await client.delete(f"/api/v1/events/{event['id']}")).status_code == 204
    assert (await client.get(f"/api/v1/events/{event['id']}")).status_code == 404
    assert (await client.get("/api/v1/events", params=DAY)).json() == []


async def test_imported_events_are_read_only(client, session):
    source = CalendarSource(name="Teams", url="https://example.com/x.ics")
    session.add(source)
    await session.flush()
    imported = Event(
        title="Daily",
        start_at=datetime(2026, 10, 12, 9, tzinfo=TZ),
        source="ics_import",
        calendar_source_id=source.id,
        external_id="abc",
    )
    session.add(imported)
    await session.commit()

    resp = await client.patch(f"/api/v1/events/{imported.id}", json={"title": "Anders"})
    assert resp.status_code == 409
    assert resp.json() == {"detail": "Importierte Termine sind schreibgeschützt"}
    assert (await client.delete(f"/api/v1/events/{imported.id}")).status_code == 409


async def test_range_limit(client):
    resp = await client.get("/api/v1/events", params={"from": "2026-01-01T00:00:00+01:00", "to": "2027-06-01T00:00:00+02:00"})
    assert resp.status_code == 422
    assert resp.json() == {"detail": "Der Zeitraum darf höchstens 366 Tage umfassen"}


async def test_broken_stored_rrule_does_not_break_listing(client, session):
    session.add(Event(title="Kaputt", start_at=datetime(2026, 10, 12, 8, tzinfo=TZ), rrule="FREQ=KAPUTT"))
    await session.commit()
    resp = await client.get("/api/v1/events", params=DAY)
    assert resp.status_code == 200
    assert [o["title"] for o in resp.json()] == ["Kaputt"]


async def test_blank_rrule_is_stored_as_null(client):
    event = await _event(client, rrule="")
    assert event["rrule"] is None
    occ = (await client.get("/api/v1/events", params=DAY)).json()
    assert occ[0]["is_recurring"] is False
