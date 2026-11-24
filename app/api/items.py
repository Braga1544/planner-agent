import uuid
from datetime import date

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.schemas.common import AreaSlug
from app.schemas.items import ItemCreate, ItemOut, ItemStatus, ItemType, ItemUpdate
from app.services import items as item_service

router = APIRouter(prefix="/items", tags=["items"])


@router.get("", response_model=list[ItemOut])
async def list_items(
    type_: ItemType | None = Query(None, alias="type"),
    area: AreaSlug | None = None,
    project: uuid.UUID | None = None,
    status: ItemStatus | None = None,
    due_before: date | None = None,
    q: str | None = None,
    session: AsyncSession = Depends(get_session),
):
    return await item_service.list_items(
        session, item_type=type_, area=area, project_id=project, status=status, due_before=due_before, q=q
    )


@router.post("", response_model=ItemOut, status_code=201)
async def create_item(data: ItemCreate, session: AsyncSession = Depends(get_session)):
    return await item_service.create_item(session, data)


@router.get("/{item_id}", response_model=ItemOut)
async def get_item(item_id: uuid.UUID, session: AsyncSession = Depends(get_session)):
    return await item_service.get_item(session, item_id)


@router.patch("/{item_id}", response_model=ItemOut)
async def update_item(item_id: uuid.UUID, data: ItemUpdate, session: AsyncSession = Depends(get_session)):
    return await item_service.update_item(session, item_id, data.model_dump(exclude_unset=True))


@router.delete("/{item_id}", response_model=ItemOut)
async def archive_item(item_id: uuid.UUID, session: AsyncSession = Depends(get_session)):
    return await item_service.archive_item(session, item_id)
