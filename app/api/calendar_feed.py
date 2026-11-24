import hmac

from fastapi import APIRouter, Depends, HTTPException, Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import Settings, get_settings
from app.db import get_session
from app.services import events as event_service
from app.services.calendar_feed import build_feed

feed_router = APIRouter(tags=["calendar"])


@feed_router.get("/calendar/{token}.ics")
async def ics_feed(
    token: str,
    session: AsyncSession = Depends(get_session),
    settings: Settings = Depends(get_settings),
) -> Response:
    expected = settings.ics_feed_token
    if not expected or not hmac.compare_digest(token.encode(), expected.encode()):
        raise HTTPException(status_code=404, detail="Nicht gefunden")
    events = await event_service.list_local_events(session)
    return Response(content=build_feed(events, settings.tz), media_type="text/calendar; charset=utf-8")
