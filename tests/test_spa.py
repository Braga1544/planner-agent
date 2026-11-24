import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.config import Settings
from app.main import create_app

INDEX = '<!doctype html><div id="root"></div>'


@pytest.fixture
def dist(tmp_path):
    d = tmp_path / "dist"
    (d / "assets").mkdir(parents=True)
    (d / "index.html").write_text(INDEX)
    (d / "assets" / "app.js").write_text("console.log(1)")
    (d / "favicon.svg").write_text("<svg/>")
    return d


def _settings(dist_dir: str) -> Settings:
    return Settings(
        _env_file=None,
        scheduler_enabled=False,
        anthropic_api_key="test",
        web_dist_dir=dist_dir,
    )


@pytest_asyncio.fixture
async def spa(app, dist, session):
    from app.db import get_session
    from app.services.tokens import create_token

    spa_app = create_app(_settings(str(dist)))

    async def _session():
        yield session

    spa_app.dependency_overrides[get_session] = _session
    _, raw = await create_token(session, "spa")
    async with AsyncClient(
        transport=ASGITransport(app=spa_app),
        base_url="http://test",
        headers={"Authorization": f"Bearer {raw}"},
    ) as c:
        yield c


async def test_root_serves_index_no_cache(spa):
    r = await spa.get("/")
    assert r.status_code == 200
    assert r.text == INDEX
    assert r.headers["cache-control"] == "no-cache"


@pytest.mark.parametrize("path", ["/kalender", "/bereiche/hobby"])
async def test_client_routes_fall_back_to_index(spa, path):
    r = await spa.get(path)
    assert r.status_code == 200
    assert r.text == INDEX


async def test_assets_are_immutable(spa):
    r = await spa.get("/assets/app.js")
    assert r.status_code == 200
    assert r.text == "console.log(1)"
    assert r.headers["cache-control"] == "public, max-age=31536000, immutable"


async def test_static_file_in_dist(spa):
    r = await spa.get("/favicon.svg")
    assert r.status_code == 200
    assert r.text == "<svg/>"


async def test_unknown_api_path_is_json_404(spa):
    r = await spa.get("/api/v1/does-not-exist")
    assert r.status_code == 404
    assert r.headers["content-type"].startswith("application/json")


async def test_health_not_shadowed(spa):
    r = await spa.get("/health")
    assert r.json() == {"status": "ok"}


async def test_wrong_calendar_feed_is_404(spa):
    r = await spa.get("/calendar/wrong.ics")
    assert r.status_code == 404
    assert INDEX not in r.text


@pytest.mark.parametrize(
    "path", ["/..%2f..%2fpyproject.toml", "/../app/main.py", "/%2e%2e/%2e%2e/pyproject.toml"]
)
async def test_path_traversal_never_leaks(spa, path):
    r = await spa.get(path)
    assert r.status_code in (200, 404)
    assert "[project]" not in r.text
    assert "create_app" not in r.text
    if r.status_code == 200:
        assert r.text == INDEX


async def test_disabled_without_dist_dir(session):
    from app.db import get_session

    app = create_app(_settings(""))
    app.dependency_overrides[get_session] = lambda: session
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        assert (await c.get("/")).status_code == 404


async def test_disabled_with_missing_dir(tmp_path):
    app = create_app(_settings(str(tmp_path / "nope")))
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        assert (await c.get("/")).status_code == 404
