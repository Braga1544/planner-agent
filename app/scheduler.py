from datetime import datetime

from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.config import Settings
from app.services.calendar_import import Fetcher, SessionFactory, default_fetch, sync_all


def create_scheduler(settings: Settings, session_factory: SessionFactory, fetch: Fetcher = default_fetch) -> AsyncIOScheduler:
    scheduler = AsyncIOScheduler(timezone=settings.timezone)
    scheduler.add_job(
        sync_all,
        "interval",
        minutes=settings.ics_sync_minutes,
        args=[session_factory, fetch, settings.tz],
        id="ics-import",
        next_run_time=datetime.now(settings.tz),  # sync once right after startup
        max_instances=1,
        coalesce=True,
    )
    return scheduler
