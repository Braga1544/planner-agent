from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.api import api_router
from app.api.calendar_feed import feed_router
from app.config import Settings, get_settings
from app.db import get_session, get_sessionmaker
from app.errors import register_error_handlers
from app.scheduler import create_scheduler
from app.spa import mount_spa


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        scheduler = None
        if settings.scheduler_enabled:
            scheduler = create_scheduler(settings, get_sessionmaker())
            scheduler.start()
        yield
        if scheduler is not None:
            scheduler.shutdown(wait=False)

    app = FastAPI(title="planner-agent", version="0.1.0", lifespan=lifespan)
    register_error_handlers(app)
    if settings.cors_origin_list:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_origin_list,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    @app.get("/health")
    async def health(session: AsyncSession = Depends(get_session)) -> dict[str, str]:
        await session.execute(text("SELECT 1"))
        return {"status": "ok"}

    app.include_router(api_router)
    app.include_router(feed_router)
    mount_spa(app, settings.web_dist_dir)  # last, catch-all must not shadow anything
    return app


app = create_app()
