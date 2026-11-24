import uuid

import pytest
from httpx import ASGITransport, AsyncClient

from app.config import Settings
from app.errors import NotFound
from app.main import create_app
from app.services import tokens

PREFLIGHT = {"Origin": "http://localhost:5173", "Access-Control-Request-Method": "GET"}


async def test_me_requires_token(anon_client):
    resp = await anon_client.get("/api/v1/me")
    assert resp.status_code == 401
    assert resp.headers["www-authenticate"] == "Bearer"


async def test_me_with_valid_token(client):
    resp = await client.get("/api/v1/me")
    assert resp.status_code == 200
    assert resp.json() == {"token_name": "test"}


async def test_unknown_token_rejected(anon_client):
    resp = await anon_client.get("/api/v1/me", headers={"Authorization": "Bearer falsch"})
    assert resp.status_code == 401


async def test_revoked_token_rejected(session, anon_client):
    token, raw = await tokens.create_token(session, "iPhone")
    await tokens.revoke_token(session, token.id)
    resp = await anon_client.get("/api/v1/me", headers={"Authorization": f"Bearer {raw}"})
    assert resp.status_code == 401


async def test_token_is_stored_hashed_and_last_used_is_updated(session, anon_client):
    token, raw = await tokens.create_token(session, "Web")
    assert token.token_hash != raw and len(token.token_hash) == 64
    assert token.last_used_at is None
    resp = await anon_client.get("/api/v1/me", headers={"Authorization": f"Bearer {raw}"})
    assert resp.status_code == 200
    assert token.last_used_at is not None


async def test_list_tokens_contains_created(session):
    await tokens.create_token(session, "iPhone")
    assert "iPhone" in [t.name for t in await tokens.list_tokens(session)]


async def test_revoke_unknown_token_raises(session):
    with pytest.raises(NotFound):
        await tokens.revoke_token(session, uuid.uuid4())


async def test_cors_disabled_by_default(anon_client):
    resp = await anon_client.options("/api/v1/me", headers=PREFLIGHT)
    assert "access-control-allow-origin" not in resp.headers


async def test_cors_enabled_via_settings():
    app = create_app(Settings(_env_file=None, cors_origins="http://localhost:5173", scheduler_enabled=False))
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        resp = await c.options("/api/v1/me", headers=PREFLIGHT)
    assert resp.headers["access-control-allow-origin"] == "http://localhost:5173"
