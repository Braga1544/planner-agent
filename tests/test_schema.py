import datetime as dt

import pytest
from sqlalchemy import select, text
from sqlalchemy.exc import IntegrityError

from app.models import Area, Item


async def test_areas_are_seeded_in_order(session):
    areas = (await session.scalars(select(Area).order_by(Area.position))).all()
    assert [a.slug for a in areas] == ["work", "business", "hobby", "personal"]
    assert areas[1].name == "Business"
    assert areas[2].name == "Hobby"


async def test_item_defaults_and_search_vector(session):
    item = Item(area="personal", type="note", title="Rechnungen bezahlen", body="Stromanbieter")
    session.add(item)
    await session.flush()
    assert item.status == "open" and item.priority == "normal"
    hits = await session.scalar(
        text("SELECT count(*) FROM items WHERE search_vector @@ websearch_to_tsquery('german', 'Rechnung')")
    )
    assert hits == 1


async def test_due_date_only_allowed_for_todos(session):
    session.add(Item(area="personal", type="idea", title="x", due_date=dt.date(2026, 10, 10)))
    with pytest.raises(IntegrityError):
        await session.flush()
