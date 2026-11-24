from httpx import ASGITransport, AsyncClient


async def test_unhandled_exception_returns_json_500(app):
    @app.get("/boom")
    async def boom():
        raise RuntimeError("kaputt")

    transport = ASGITransport(app=app, raise_app_exceptions=False)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        resp = await c.get("/boom")
        assert resp.status_code == 500
        assert resp.json() == {"detail": "Interner Serverfehler"}
        # leave the fastapi handlers alone
        assert (await c.get("/api/v1/conversations")).status_code == 401
