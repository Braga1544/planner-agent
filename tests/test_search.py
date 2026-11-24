async def test_search_finds_items_projects_and_events(client):
    await client.post(
        "/api/v1/projects", json={"area": "hobby", "name": "Fotobuch", "description": "Urlaubsfotos"}
    )
    await client.post(
        "/api/v1/items",
        json={"type": "note", "area": "hobby", "title": "Fotobuch Layout", "body": "Seiten planen"},
    )
    await client.post(
        "/api/v1/events", json={"title": "Fotobuch Review", "start_at": "2026-10-12T18:00:00+02:00"}
    )
    await client.post("/api/v1/items", json={"type": "note", "area": "personal", "title": "Einkaufsliste"})

    res = (await client.get("/api/v1/search", params={"q": "Fotobuch"})).json()
    assert [i["title"] for i in res["items"]] == ["Fotobuch Layout"]
    assert [p["name"] for p in res["projects"]] == ["Fotobuch"]
    assert [e["title"] for e in res["events"]] == ["Fotobuch Review"]


async def test_search_excludes_archived_items(client):
    item = (await client.post("/api/v1/items", json={"type": "note", "area": "personal", "title": "Steuer"})).json()
    await client.delete(f"/api/v1/items/{item['id']}")
    res = (await client.get("/api/v1/search", params={"q": "Steuer"})).json()
    assert res["items"] == []


async def test_search_handles_operator_characters(client):
    resp = await client.get("/api/v1/search", params={"q": 'C# -"kaputt'})
    assert resp.status_code == 200


async def test_search_requires_query(client):
    resp = await client.get("/api/v1/search", params={"q": "   "})
    assert resp.status_code == 422
