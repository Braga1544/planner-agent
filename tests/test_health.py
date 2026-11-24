async def test_health_returns_ok(anon_client):
    resp = await anon_client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {"status": "ok"}


async def test_domain_errors_are_mapped_to_status_codes(app, anon_client):
    from app.errors import Conflict, Invalid, NotFound

    errors = {"nf": NotFound("weg"), "inv": Invalid("kaputt"), "conf": Conflict("besetzt")}

    async def boom(kind: str):
        raise errors[kind]

    app.add_api_route("/boom/{kind}", boom)
    for kind, code, detail in [("nf", 404, "weg"), ("inv", 422, "kaputt"), ("conf", 409, "besetzt")]:
        resp = await anon_client.get(f"/boom/{kind}")
        assert resp.status_code == code
        assert resp.json() == {"detail": detail}
