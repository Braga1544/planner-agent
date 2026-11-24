from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import Invalid
from app.models import Event, Item, Project
from app.schemas.agenda import SearchResults
from app.schemas.events import EventOut
from app.schemas.items import ItemOut
from app.schemas.projects import ProjectOut
from app.services import fts


async def search(session: AsyncSession, q: str, limit: int = 20) -> SearchResults:
    q = q.strip()
    if not q:
        raise Invalid("Suchbegriff fehlt")
    items = await session.scalars(
        select(Item)
        .where(Item.status != "archived", fts.matches("items", q))
        .order_by(fts.rank("items", q).desc())
        .limit(limit)
    )
    projects = await session.scalars(
        select(Project).where(fts.matches("projects", q)).order_by(fts.rank("projects", q).desc()).limit(limit)
    )
    events = await session.scalars(
        select(Event)
        .where(Event.deleted_at.is_(None), fts.matches("events", q))
        .order_by(fts.rank("events", q).desc())
        .limit(limit)
    )
    return SearchResults(
        items=[ItemOut.model_validate(i) for i in items],
        projects=[ProjectOut.model_validate(p) for p in projects],
        events=[EventOut.model_validate(e) for e in events],
    )
