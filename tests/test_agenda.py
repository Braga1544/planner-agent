async def _event(client, title, start, end=None):
    body = {"title": title, "start_at": start}
    if end:
        body["end_at"] = end
    resp = await client.post("/api/v1/events", json=body)
    assert resp.status_code == 201, resp.text


async def _todo(client, title, due=None, **extra):
    body = {"type": "todo", "area": "personal", "title": title, **extra}
    if due:
        body["due_date"] = due
    resp = await client.post("/api/v1/items", json=body)
    assert resp.status_code == 201, resp.text
    return resp.json()


async def test_agenda_today_combines_events_due_and_overdue(client):
    await _event(client, "Meeting", "2026-10-09T14:00:00+02:00", "2026-10-09T15:00:00+02:00")
    await _event(client, "Morgen", "2026-10-10T10:00:00+02:00")
    await _todo(client, "Heute fällig", "2026-10-09")
    await _todo(client, "Überfällig", "2026-10-05")
    done = await _todo(client, "Erledigt", "2026-10-05")
    await client.patch(f"/api/v1/items/{done['id']}", json={"status": "done"})
    await _todo(client, "Irgendwann")
    await client.post("/api/v1/items", json={"type": "idea", "area": "personal", "title": "Idee"})

    agenda = (await client.get("/api/v1/agenda")).json()
    assert agenda["start"] == agenda["end"] == "2026-10-09"
    assert [e["title"] for e in agenda["events"]] == ["Meeting"]
    assert [t["title"] for t in agenda["due_todos"]] == ["Heute fällig"]
    assert [t["title"] for t in agenda["overdue_todos"]] == ["Überfällig"]


async def test_agenda_future_range_has_no_overdue(client):
    await _todo(client, "Überfällig", "2026-10-05")
    await _todo(client, "Nächste Woche", "2026-10-14")
    agenda = (await client.get("/api/v1/agenda", params={"from": "2026-10-12", "to": "2026-10-18"})).json()
    assert agenda["overdue_todos"] == []
    assert [t["title"] for t in agenda["due_todos"]] == ["Nächste Woche"]


async def test_agenda_date_param(client):
    await _event(client, "Zahnarzt", "2026-10-12T09:00:00+02:00")
    agenda = (await client.get("/api/v1/agenda", params={"date": "2026-10-12"})).json()
    assert [e["title"] for e in agenda["events"]] == ["Zahnarzt"]


async def test_agenda_rejects_inverted_range(client):
    resp = await client.get("/api/v1/agenda", params={"from": "2026-10-12", "to": "2026-10-10"})
    assert resp.status_code == 422
