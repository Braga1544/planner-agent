import uuid


async def _project(client, area="hobby", name="Gartenhaus"):
    resp = await client.post("/api/v1/projects", json={"area": area, "name": name})
    assert resp.status_code == 201, resp.text
    return resp.json()


async def _item(client, **payload):
    body = {"type": "todo", "area": "personal", "title": "Milch kaufen", **payload}
    resp = await client.post("/api/v1/items", json=body)
    assert resp.status_code == 201, resp.text
    return resp.json()


async def test_create_todo_with_due_date_and_project(client):
    project = await _project(client)
    item = await _item(
        client, area="hobby", project_id=project["id"], title="Material bestellen", due_date="2026-10-16", priority="high"
    )
    assert item["status"] == "open"
    assert item["due_date"] == "2026-10-16"
    assert item["project_id"] == project["id"]
    assert item["completed_at"] is None


async def test_due_date_rejected_for_ideas(client):
    resp = await client.post(
        "/api/v1/items", json={"type": "idea", "area": "personal", "title": "X", "due_date": "2026-10-10"}
    )
    assert resp.status_code == 422
    assert resp.json() == {"detail": "Fälligkeitsdatum ist nur bei ToDos erlaubt"}


async def test_project_must_belong_to_same_area(client):
    project = await _project(client, area="hobby")
    resp = await client.post(
        "/api/v1/items", json={"type": "todo", "area": "personal", "title": "X", "project_id": project["id"]}
    )
    assert resp.status_code == 422
    assert resp.json() == {"detail": "Projekt gehört zu einem anderen Bereich"}


async def test_unknown_project_is_404(client):
    resp = await client.post(
        "/api/v1/items", json={"type": "todo", "area": "personal", "title": "X", "project_id": str(uuid.uuid4())}
    )
    assert resp.status_code == 404


async def test_done_sets_and_reopen_clears_completed_at(client):
    item = await _item(client)
    done = (await client.patch(f"/api/v1/items/{item['id']}", json={"status": "done"})).json()
    assert done["completed_at"] is not None
    reopened = (await client.patch(f"/api/v1/items/{item['id']}", json={"status": "open"})).json()
    assert reopened["completed_at"] is None


async def test_converting_todo_to_idea_clears_due_date(client):
    item = await _item(client, due_date="2026-10-12")
    resp = await client.patch(f"/api/v1/items/{item['id']}", json={"type": "idea"})
    assert resp.status_code == 200
    assert resp.json()["type"] == "idea"
    assert resp.json()["due_date"] is None


async def test_converting_idea_to_todo_with_due_date(client):
    item = await _item(client, type="idea", title="Fotobuch")
    resp = await client.patch(f"/api/v1/items/{item['id']}", json={"type": "todo", "due_date": "2026-11-01"})
    assert resp.status_code == 200
    assert resp.json()["due_date"] == "2026-11-01"


async def test_update_rejects_null_title(client):
    item = await _item(client)
    resp = await client.patch(f"/api/v1/items/{item['id']}", json={"title": None})
    assert resp.status_code == 422


async def test_list_filters_and_hides_archived(client):
    await _item(client, title="A", due_date="2026-10-12")
    await _item(client, title="B", due_date="2026-10-20")
    c = await _item(client, type="idea", area="work", title="C")
    assert (await client.delete(f"/api/v1/items/{c['id']}")).status_code == 200

    titles = [i["title"] for i in (await client.get("/api/v1/items")).json()]
    assert titles == ["A", "B"]
    due = (await client.get("/api/v1/items", params={"due_before": "2026-10-15"})).json()
    assert [i["title"] for i in due] == ["A"]
    archived = (await client.get("/api/v1/items", params={"type": "idea", "status": "archived"})).json()
    assert [i["title"] for i in archived] == ["C"]
    assert (await client.get("/api/v1/items", params={"area": "work"})).json() == []


async def test_list_orders_by_due_date_then_priority(client):
    await _item(client, title="X", priority="high")
    await _item(client, title="Y", due_date="2026-10-12", priority="low")
    await _item(client, title="Z", due_date="2026-10-12", priority="high")
    titles = [i["title"] for i in (await client.get("/api/v1/items")).json()]
    assert titles == ["Z", "Y", "X"]


async def test_fulltext_search_uses_german_stemming(client):
    await _item(client, type="note", title="Rechnungen für Kunden")
    await _item(client, type="note", title="Einkaufsliste")
    resp = await client.get("/api/v1/items", params={"q": "Rechnung"})
    assert [i["title"] for i in resp.json()] == ["Rechnungen für Kunden"]


async def test_delete_archives_item(client):
    item = await _item(client)
    resp = await client.delete(f"/api/v1/items/{item['id']}")
    assert resp.status_code == 200
    assert resp.json()["status"] == "archived"
    assert (await client.get(f"/api/v1/items/{item['id']}")).json()["status"] == "archived"


async def test_project_detail_lists_open_items(client):
    project = await _project(client)
    await _item(client, area="hobby", project_id=project["id"], title="offen")
    done = await _item(client, area="hobby", project_id=project["id"], title="erledigt")
    await client.patch(f"/api/v1/items/{done['id']}", json={"status": "done"})
    await _item(client, type="idea", area="hobby", project_id=project["id"], title="Idee")

    detail = (await client.get(f"/api/v1/projects/{project['id']}")).json()
    assert detail["name"] == "Gartenhaus"
    assert sorted(i["title"] for i in detail["open_items"]) == ["Idee", "offen"]
