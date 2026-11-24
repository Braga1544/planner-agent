import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.schemas.common import AreaSlug
from app.schemas.projects import AreaOut, ProjectCreate, ProjectDetail, ProjectOut, ProjectStatus, ProjectUpdate
from app.services import items as item_service
from app.services import projects as project_service

router = APIRouter(tags=["projects"])


@router.get("/areas", response_model=list[AreaOut])
async def list_areas(session: AsyncSession = Depends(get_session)):
    return await project_service.list_areas(session)


@router.get("/projects", response_model=list[ProjectOut])
async def list_projects(
    area: AreaSlug | None = None,
    status: ProjectStatus | None = None,
    session: AsyncSession = Depends(get_session),
):
    return await project_service.list_projects(session, area=area, status=status)


@router.post("/projects", response_model=ProjectOut, status_code=201)
async def create_project(data: ProjectCreate, session: AsyncSession = Depends(get_session)):
    return await project_service.create_project(session, data)


@router.get("/projects/{project_id}", response_model=ProjectDetail)
async def get_project(project_id: uuid.UUID, session: AsyncSession = Depends(get_session)):
    return await item_service.get_project_detail(session, project_id)


@router.patch("/projects/{project_id}", response_model=ProjectOut)
async def update_project(
    project_id: uuid.UUID, data: ProjectUpdate, session: AsyncSession = Depends(get_session)
):
    return await project_service.update_project(session, project_id, data.model_dump(exclude_unset=True))
