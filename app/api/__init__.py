from fastapi import APIRouter, Depends

from app.api import agenda, calendar_sources, chat, events, items, me, projects
from app.auth import require_token

api_router = APIRouter(prefix="/api/v1", dependencies=[Depends(require_token)])
for module in (me, projects, items, events, agenda, calendar_sources, chat):
    api_router.include_router(module.router)
