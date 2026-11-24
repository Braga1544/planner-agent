from datetime import timedelta

from app.config import Settings
from app.scheduler import create_scheduler


def test_scheduler_registers_ics_job():
    scheduler = create_scheduler(Settings(_env_file=None, ics_sync_minutes=15), session_factory=lambda: None)
    job = scheduler.get_job("ics-import")
    assert job is not None
    assert job.trigger.interval == timedelta(minutes=15)
