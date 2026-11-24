import uuid
from datetime import date
from typing import Any

from sqlalchemy import case, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import Invalid, NotFound, reject_nulls
from app.models import Item, utcnow
from app.schemas.items import ItemCreate, ItemOut
from app.schemas.projects import ProjectDetail, ProjectOut
from app.services import fts
from app.services import projects as project_service

PRIORITY_RANK = case({"high": 0, "normal": 1, "low": 2}, value=Item.priority)
DUE_ONLY_TODO = "Fälligkeitsdatum ist nur bei ToDos erlaubt"
_NOT_NULL = ("type", "area", "title", "status", "priority")


async def _check_project(session: AsyncSession, project_id: uuid.UUID, area: str) -> None:
    project = await project_service.get_project(session, project_id)
    if project.area != area:
        raise Invalid("Projekt gehört zu einem anderen Bereich")


async def create_item(session: AsyncSession, data: ItemCreate) -> Item:
    if data.due_date is not None and data.type != "todo":
        raise Invalid(DUE_ONLY_TODO)
    if data.project_id is not None:
        await _check_project(session, data.project_id, data.area)
    item = Item(**data.model_dump())
    session.add(item)
    await session.commit()
    return item


async def get_item(session: AsyncSession, item_id: uuid.UUID) -> Item:
    item = await session.get(Item, item_id)
    if item is None:
        raise NotFound("Eintrag nicht gefunden")
    return item


async def list_items(
    session: AsyncSession,
    *,
    item_type: str | None = None,
    area: str | None = None,
    project_id: uuid.UUID | None = None,
    status: str | None = None,
    due_before: date | None = None,
    q: str | None = None,
    limit: int = 100,
) -> list[Item]:
    stmt = select(Item)
    if item_type:
        stmt = stmt.where(Item.type == item_type)
    if area:
        stmt = stmt.where(Item.area == area)
    if project_id:
        stmt = stmt.where(Item.project_id == project_id)
    stmt = stmt.where(Item.status == status) if status else stmt.where(Item.status != "archived")
    if due_before:
        stmt = stmt.where(Item.due_date <= due_before)
    if q:
        stmt = stmt.where(fts.matches("items", q))
    stmt = stmt.order_by(Item.due_date.asc().nulls_last(), PRIORITY_RANK, Item.created_at.desc()).limit(limit)
    return list(await session.scalars(stmt))


async def update_item(session: AsyncSession, item_id: uuid.UUID, changes: dict[str, Any]) -> Item:
    item = await get_item(session, item_id)
    reject_nulls(changes, _NOT_NULL)
    new_type = changes.get("type", item.type)
    new_area = changes.get("area", item.area)
    new_project = changes["project_id"] if "project_id" in changes else item.project_id
    if changes.get("due_date") is not None and new_type != "todo":
        raise Invalid(DUE_ONLY_TODO)
    if new_project is not None and ("project_id" in changes or "area" in changes):
        await _check_project(session, new_project, new_area)

    new_status = changes.get("status", item.status)
    if new_status != item.status:
        if new_status == "done":
            item.completed_at = utcnow()
        elif new_status == "open":
            item.completed_at = None
    for key, value in changes.items():
        setattr(item, key, value)
    if item.type != "todo":
        item.due_date = None
    await session.commit()
    return item


async def archive_item(session: AsyncSession, item_id: uuid.UUID) -> Item:
    return await update_item(session, item_id, {"status": "archived"})


async def get_project_detail(session: AsyncSession, project_id: uuid.UUID) -> ProjectDetail:
    project = await project_service.get_project(session, project_id)
    open_items = await list_items(session, project_id=project_id, status="open")
    return ProjectDetail(
        **ProjectOut.model_validate(project).model_dump(),
        open_items=[ItemOut.model_validate(i) for i in open_items],
    )
