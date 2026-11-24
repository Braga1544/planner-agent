from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import Invalid
from app.models import Item
from app.schemas.agenda import Agenda
from app.schemas.items import ItemOut
from app.services import events as event_service
from app.services.items import PRIORITY_RANK


async def get_agenda(session: AsyncSession, start: date, end: date, today: date, tz: ZoneInfo) -> Agenda:
    if end < start:
        raise Invalid("Das Enddatum liegt vor dem Startdatum")
    range_start = datetime.combine(start, time.min, tz)
    range_end = datetime.combine(end + timedelta(days=1), time.min, tz)
    events = await event_service.list_occurrences(session, range_start, range_end, tz)

    open_todos = select(Item).where(Item.type == "todo", Item.status == "open")
    due = await session.scalars(
        open_todos.where(Item.due_date >= start, Item.due_date <= end).order_by(Item.due_date, PRIORITY_RANK)
    )
    due_todos = [ItemOut.model_validate(i) for i in due]

    overdue_todos: list[ItemOut] = []
    if start <= today <= end:
        overdue = await session.scalars(open_todos.where(Item.due_date < start).order_by(Item.due_date, PRIORITY_RANK))
        overdue_todos = [ItemOut.model_validate(i) for i in overdue]

    return Agenda(start=start, end=end, events=events, due_todos=due_todos, overdue_todos=overdue_todos)
