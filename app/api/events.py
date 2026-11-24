import uuid

from fastapi import APIRouter, Depends, Query, Response
from pydantic import AwareDatetime
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.db import get_session
from app.schemas.common import AreaSlug
from app.schemas.events import EventCreate, EventOut, EventUpdate, Occurrence
from app.services import events as event_service

router = APIRouter(prefix="/events", tags=["events"])


@router.get("", response_model=list[Occurrence])
async def list_events(
    start: AwareDatetime = Query(alias="from"),
    end: AwareDatetime = Query(alias="to"),
    area: AreaSlug | None = None,
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
):
    return await event_service.list_occurrences(session, start, end, settings.tz, area=area)


@router.post("", response_model=EventOut, status_code=201)
async def create_event(
    data: EventCreate, session: AsyncSession = Depends(get_session), settings: Settings = Depends(get_settings)
):
    return await event_service.create_event(session, data, settings.tz)


@router.get("/{event_id}", response_model=EventOut)
async def get_event(event_id: uuid.UUID, session: AsyncSession = Depends(get_session)):
    return await event_service.get_event(session, event_id)


@router.patch("/{event_id}", response_model=EventOut)
async def update_event(
    event_id: uuid.UUID,
    data: EventUpdate,
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
):
    return await event_service.update_event(session, event_id, data.model_dump(exclude_unset=True), settings.tz)


@router.delete("/{event_id}", status_code=204)
async def delete_event(event_id: uuid.UUID, session: AsyncSession = Depends(get_session)) -> Response:
    await event_service.delete_event(session, event_id)
    return Response(status_code=204)
