from datetime import date, datetime

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.clock import get_now
from app.config import Settings, get_settings
from app.db import get_session
from app.schemas.agenda import Agenda, SearchResults
from app.services import agenda as agenda_service
from app.services import search as search_service

router = APIRouter(tags=["agenda"])


@router.get("/agenda", response_model=Agenda)
async def get_agenda(
    day: date | None = Query(None, alias="date"),
    start: date | None = Query(None, alias="from"),
    end: date | None = Query(None, alias="to"),
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
    now: datetime = Depends(get_now),
):
    today = now.date()
    if day:
        start = end = day
    else:
        start = start or today
        end = end or start
    return await agenda_service.get_agenda(session, start, end, today, settings.tz)


@router.get("/search", response_model=SearchResults)
async def search(q: str, session: AsyncSession = Depends(get_session)):
    return await search_service.search(session, q)
