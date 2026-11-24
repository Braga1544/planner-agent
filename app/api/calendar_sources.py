import uuid

from fastapi import APIRouter, Depends, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.db import get_session
from app.schemas.calendar import CalendarSourceCreate, CalendarSourceOut, CalendarSourceUpdate, SyncResult
from app.services import calendar_sources as source_service
from app.services.calendar_import import Fetcher, default_fetch, sync_source

router = APIRouter(prefix="/calendar-sources", tags=["calendar"])


def get_fetcher() -> Fetcher:
    return default_fetch


@router.get("", response_model=list[CalendarSourceOut])
async def list_sources(session: AsyncSession = Depends(get_session)):
    return await source_service.list_sources(session)


@router.post("", response_model=CalendarSourceOut, status_code=201)
async def create_source(data: CalendarSourceCreate, session: AsyncSession = Depends(get_session)):
    return await source_service.create_source(session, data)


@router.patch("/{source_id}", response_model=CalendarSourceOut)
async def update_source(
    source_id: uuid.UUID, data: CalendarSourceUpdate, session: AsyncSession = Depends(get_session)
):
    return await source_service.update_source(session, source_id, data.model_dump(exclude_unset=True))


@router.delete("/{source_id}", status_code=204)
async def delete_source(source_id: uuid.UUID, session: AsyncSession = Depends(get_session)) -> Response:
    await source_service.delete_source(session, source_id)
    return Response(status_code=204)


@router.post("/{source_id}/sync", response_model=SyncResult)
async def sync_now(
    source_id: uuid.UUID,
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
    fetch: Fetcher = Depends(get_fetcher),
):
    source = await source_service.get_source(session, source_id)
    return await sync_source(session, source, fetch, settings.tz)
