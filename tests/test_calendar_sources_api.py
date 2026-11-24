from app.api.calendar_sources import get_fetcher
from tests.helpers import fixture_fetcher

DAY = {"from": "2026-10-12T00:00:00+02:00", "to": "2026-10-13T00:00:00+02:00"}


async def test_crud_and_manual_sync(client, app):
    app.dependency_overrides[get_fetcher] = lambda: fixture_fetcher("teams_v1.ics")

    resp = await client.post(
        "/api/v1/calendar-sources",
        json={"name": "Teams", "url": "webcal://outlook.office365.com/x.ics", "area": "work"},
    )
    assert resp.status_code == 201, resp.text
    source_id = resp.json()["id"]

    sync = (await client.post(f"/api/v1/calendar-sources/{source_id}/sync")).json()
    assert sync == {"created": 5, "updated": 0, "deleted": 0, "error": None}

    listed = (await client.get("/api/v1/calendar-sources")).json()
    assert listed[0]["last_synced_at"] is not None

    resp = await client.patch(f"/api/v1/calendar-sources/{source_id}", json={"enabled": False})
    assert resp.json()["enabled"] is False

    assert (await client.delete(f"/api/v1/calendar-sources/{source_id}")).status_code == 204
    titles = [o["title"] for o in (await client.get("/api/v1/events", params=DAY)).json()]
    assert "Sprint Planning" not in titles


async def test_rejects_non_http_url(client):
    resp = await client.post("/api/v1/calendar-sources", json={"name": "X", "url": "ftp://example.com/x.ics"})
    assert resp.status_code == 422
