import uuid
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import NotFound, reject_nulls
from app.models import Area, Project
from app.schemas.projects import ProjectCreate

_NOT_NULL = ("name", "status")


async def list_areas(session: AsyncSession) -> list[Area]:
    return list(await session.scalars(select(Area).order_by(Area.position)))


async def create_project(session: AsyncSession, data: ProjectCreate) -> Project:
    project = Project(**data.model_dump())
    session.add(project)
    await session.commit()
    return project


async def get_project(session: AsyncSession, project_id: uuid.UUID) -> Project:
    project = await session.get(Project, project_id)
    if project is None:
        raise NotFound("Projekt nicht gefunden")
    return project


async def list_projects(
    session: AsyncSession, *, area: str | None = None, status: str | None = None
) -> list[Project]:
    stmt = select(Project).order_by(Project.area, Project.name)
    if area:
        stmt = stmt.where(Project.area == area)
    stmt = stmt.where(Project.status == status) if status else stmt.where(Project.status != "archived")
    return list(await session.scalars(stmt))


async def update_project(session: AsyncSession, project_id: uuid.UUID, changes: dict[str, Any]) -> Project:
    project = await get_project(session, project_id)
    reject_nulls(changes, _NOT_NULL)
    for key, value in changes.items():
        setattr(project, key, value)
    await session.commit()
    return project
