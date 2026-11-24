from datetime import datetime

from fastapi import Depends

from app.config import Settings, get_settings


def get_now(settings: Settings = Depends(get_settings)) -> datetime:
    return datetime.now(settings.tz)
