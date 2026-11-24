import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import NotFound, reject_nulls
from app.models import CalendarSource
from app.schemas.calendar import CalendarSourceCreate

_NOT_NULL = ("name", "url", "enabled")


async def list_sources(session: AsyncSession) -> list[CalendarSource]:
    return list(await session.scalars(select(CalendarSource).order_by(CalendarSource.name)))


async def create_source(session: AsyncSession, data: CalendarSourceCreate) -> CalendarSource:
    source = CalendarSource(**data.model_dump())
    session.add(source)
    await session.commit()
    return source


async def get_source(session: AsyncSession, source_id: uuid.UUID) -> CalendarSource:
    source = await session.get(CalendarSource, source_id)
    if source is None:
        raise NotFound("Kalenderquelle nicht gefunden")
    return source


async def update_source(session: AsyncSession, source_id: uuid.UUID, changes: dict[str, Any]) -> CalendarSource:
    source = await get_source(session, source_id)
    reject_nulls(changes, _NOT_NULL)
    for key, value in changes.items():
        setattr(source, key, value)
    await session.commit()
    return source


async def delete_source(session: AsyncSession, source_id: uuid.UUID) -> None:
    source = await get_source(session, source_id)
    await session.delete(source)  # imported events go away via ON DELETE CASCADE
    await session.commit()
