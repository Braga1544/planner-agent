import uuid


async def _project(client, **payload):
    resp = await client.post("/api/v1/projects", json={"area": "hobby", "name": "Gartenhaus", **payload})
    assert resp.status_code == 201, resp.text
    return resp.json()


async def test_list_areas(client):
    resp = await client.get("/api/v1/areas")
    assert resp.status_code == 200
    assert [a["slug"] for a in resp.json()] == ["work", "business", "hobby", "personal"]


async def test_create_and_get_project(client):
    project = await _project(client, description="## Ziel\nNeues Gartenhaus")
    assert project["status"] == "active"
    assert project["area"] == "hobby"
    resp = await client.get(f"/api/v1/projects/{project['id']}")
    assert resp.status_code == 200
    assert resp.json()["name"] == "Gartenhaus"


async def test_create_project_rejects_unknown_area_and_fields(client):
    assert (await client.post("/api/v1/projects", json={"area": "nope", "name": "X"})).status_code == 422
    resp = await client.post("/api/v1/projects", json={"area": "personal", "name": "X", "foo": 1})
    assert resp.status_code == 422


async def test_list_projects_filters_and_hides_archived(client):
    kunde = await _project(client, area="work", name="Kunde A")
    await _project(client, area="personal", name="Umzug")
    await client.patch(f"/api/v1/projects/{kunde['id']}", json={"status": "archived"})

    names = [p["name"] for p in (await client.get("/api/v1/projects")).json()]
    assert "Umzug" in names and "Kunde A" not in names

    archived = (await client.get("/api/v1/projects", params={"status": "archived"})).json()
    assert [p["name"] for p in archived] == ["Kunde A"]

    personal = (await client.get("/api/v1/projects", params={"area": "personal"})).json()
    assert [p["name"] for p in personal] == ["Umzug"]


async def test_update_project(client):
    project = await _project(client)
    resp = await client.patch(f"/api/v1/projects/{project['id']}", json={"description": "neu", "status": "paused"})
    assert resp.status_code == 200
    assert resp.json()["description"] == "neu"
    assert resp.json()["status"] == "paused"


async def test_update_project_rejects_null_name(client):
    project = await _project(client)
    resp = await client.patch(f"/api/v1/projects/{project['id']}", json={"name": None})
    assert resp.status_code == 422
    assert resp.json() == {"detail": "Feld 'name' darf nicht leer sein"}


async def test_unknown_project_is_404(client):
    resp = await client.get(f"/api/v1/projects/{uuid.uuid4()}")
    assert resp.status_code == 404
    assert resp.json() == {"detail": "Projekt nicht gefunden"}
