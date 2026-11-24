import os
import subprocess
import sys
from collections.abc import AsyncIterator, Iterator
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient
from pytest_asyncio import is_async_test
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, create_async_engine
from testcontainers.community.postgres import PostgresContainer

ROOT = Path(__file__).resolve().parents[1]
NOW = datetime(2026, 10, 9, 20, 11, tzinfo=ZoneInfo("Europe/Berlin"))


def pytest_collection_modifyitems(items):
    # one loop for all tests because of the session engine
    marker = pytest.mark.asyncio(loop_scope="session")
    for item in items:
        if is_async_test(item):
            item.add_marker(marker, append=False)


@pytest.fixture(scope="session")
def database_url() -> Iterator[str]:
    with PostgresContainer("postgres:16-alpine", driver="asyncpg") as pg:
        url = pg.get_connection_url()
        env = {**os.environ, "DATABASE_URL": url}
        subprocess.run(
            [sys.executable, "-m", "alembic", "upgrade", "head"], cwd=ROOT, env=env, check=True
        )
        yield url


@pytest_asyncio.fixture(scope="session", loop_scope="session")
async def engine(database_url: str) -> AsyncIterator[AsyncEngine]:
    eng = create_async_engine(database_url)
    yield eng
    await eng.dispose()


@pytest_asyncio.fixture
async def session(engine: AsyncEngine) -> AsyncIterator[AsyncSession]:
    # outer tx per test, rollback at the end
    # commit() in services only releases savepoints
    async with engine.connect() as conn:
        trans = await conn.begin()
        s = AsyncSession(bind=conn, expire_on_commit=False, join_transaction_mode="create_savepoint")
        try:
            yield s
        finally:
            await s.close()
            await trans.rollback()


@pytest.fixture
def settings():
    from app.config import Settings

    return Settings(
        _env_file=None,
        ics_feed_token="feed-secret",
        cors_origins="",
        scheduler_enabled=False,
        anthropic_api_key="test",
    )


@pytest.fixture
def app(session, settings):
    from app.clock import get_now
    from app.config import get_settings
    from app.db import get_session, get_session_factory
    from app.main import create_app

    application = create_app(settings)

    async def _session():
        yield session

    @asynccontextmanager
    async def _factory():
        yield session

    application.dependency_overrides[get_session] = _session
    application.dependency_overrides[get_session_factory] = lambda: _factory
    application.dependency_overrides[get_settings] = lambda: settings
    application.dependency_overrides[get_now] = lambda: NOW
    return application


@pytest_asyncio.fixture
async def anon_client(app) -> AsyncIterator[AsyncClient]:
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest_asyncio.fixture
async def client(app, session) -> AsyncIterator[AsyncClient]:
    from app.services.tokens import create_token

    _, raw = await create_token(session, "test")
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
        headers={"Authorization": f"Bearer {raw}"},
    ) as c:
        yield c
