import json
from datetime import datetime
from zoneinfo import ZoneInfo

from app.agent.tools import ToolContext, run_tool, tool_definitions
from app.models import CalendarSource, Event

TZ = ZoneInfo("Europe/Berlin")
CTX = ToolContext(tz=TZ, now=datetime(2026, 10, 9, 20, 11, tzinfo=TZ))


def _walk(node):
    if isinstance(node, dict):
        yield node
        for value in node.values():
            yield from _walk(value)
    elif isinstance(node, list):
        for value in node:
            yield from _walk(value)


async def _call(session, name, payload):
    content, is_error = await run_tool(session, CTX, name, payload)
    return json.loads(content), is_error


def test_tool_definitions_are_clean():
    defs = tool_definitions()
    names = [d["name"] for d in defs]
    assert len(names) == len(set(names)) == 14
    for definition in defs:
        assert "strict" not in definition
        assert definition["description"]
        schema = definition["input_schema"]
        assert schema["type"] == "object"
        assert schema["additionalProperties"] is False
        for node in _walk(schema):
            assert "default" not in node
            assert not isinstance(node.get("title"), str)
            assert not ({"minLength", "maxLength", "minimum", "maximum"} & node.keys())


def test_tool_definitions_are_deterministic():
    assert json.dumps(tool_definitions()) == json.dumps(tool_definitions())


async def test_create_item_via_tool(session):
    data, is_error = await _call(
        session, "create_item", {"type": "todo", "area": "personal", "title": "Milch kaufen", "due_date": "2026-10-10"}
    )
    assert not is_error
    assert data["title"] == "Milch kaufen"
    assert data["due_date"] == "2026-10-10"


async def test_invalid_input_is_reported_as_error(session):
    data, is_error = await _call(session, "create_item", {"type": "todo", "area": "personal"})
    assert is_error
    assert data["error"] == "Ungültige Eingabe"
    assert data["details"][0]["feld"] == "title"


async def test_domain_error_is_reported_in_german(session):
    data, is_error = await _call(
        session, "create_item", {"type": "idea", "area": "personal", "title": "X", "due_date": "2026-10-10"}
    )
    assert is_error
    assert data["error"] == "Fälligkeitsdatum ist nur bei ToDos erlaubt"


async def test_unknown_tool(session):
    data, is_error = await _call(session, "fly_to_moon", {})
    assert is_error
    assert data["error"] == "Unbekanntes Tool: fly_to_moon"


async def test_create_event_with_naive_local_time(session):
    data, is_error = await _call(
        session, "create_event", {"title": "Zahnarzt", "start": "2026-10-12T14:00", "end": "2026-10-12T15:00"}
    )
    assert not is_error
    assert data["start_at"] == "2026-10-12T14:00:00+02:00"
    assert data["end_at"] == "2026-10-12T15:00:00+02:00"
    assert data["all_day"] is False


async def test_create_all_day_event_with_inclusive_end(session):
    data, is_error = await _call(session, "create_event", {"title": "Urlaub", "start": "2026-10-20", "end": "2026-10-23"})
    assert not is_error
    assert data["all_day"] is True
    assert data["start_at"] == "2026-10-20T00:00:00+02:00"
    assert data["end_at"] == "2026-10-24T00:00:00+02:00"


async def test_invalid_time_string_is_error(session):
    data, is_error = await _call(session, "create_event", {"title": "X", "start": "nächsten Dienstag"})
    assert is_error
    assert "Ungültige Datums-/Zeitangabe" in data["error"]


async def test_update_imported_event_is_error(session):
    source = CalendarSource(name="Teams", url="https://example.com/x.ics")
    session.add(source)
    await session.flush()
    imported = Event(
        title="Daily", start_at=datetime(2026, 10, 12, 9, tzinfo=TZ), source="ics_import",
        calendar_source_id=source.id, external_id="d",
    )
    session.add(imported)
    await session.commit()
    imported_id = str(imported.id)

    data, is_error = await _call(session, "update_event", {"event_id": imported_id, "title": "Anders"})
    assert is_error
    assert data["error"] == "Importierte Termine sind schreibgeschützt"


async def test_get_agenda_defaults_to_today(session):
    await _call(session, "create_item", {"type": "todo", "area": "personal", "title": "Heute", "due_date": "2026-10-09"})
    data, is_error = await _call(session, "get_agenda", {})
    assert not is_error
    assert data["start"] == "2026-10-09"
    assert [t["title"] for t in data["due_todos"]] == ["Heute"]


async def test_update_item_marks_done(session):
    item, _ = await _call(session, "create_item", {"type": "todo", "area": "personal", "title": "A"})
    data, is_error = await _call(session, "update_item", {"item_id": item["id"], "status": "done"})
    assert not is_error
    assert data["status"] == "done"
    assert data["completed_at"] is not None


async def test_get_project_returns_open_items(session):
    project, _ = await _call(session, "create_project", {"area": "hobby", "name": "Gartenhaus"})
    await _call(session, "create_item", {"type": "idea", "area": "hobby", "project_id": project["id"], "title": "Hochbeet"})
    data, is_error = await _call(session, "get_project", {"project_id": project["id"]})
    assert not is_error
    assert [i["title"] for i in data["open_items"]] == ["Hochbeet"]


async def test_every_tool_runs_with_example_input(session):
    project, err = await _call(session, "create_project", {"area": "personal", "name": "Umzug"})
    assert not err
    item, err = await _call(
        session, "create_item", {"type": "todo", "area": "personal", "project_id": project["id"], "title": "Kartons"}
    )
    assert not err
    event, err = await _call(session, "create_event", {"title": "Besichtigung", "start": "2026-10-12T10:00"})
    assert not err

    calls = [
        ("update_project", {"project_id": project["id"], "status": "paused"}),
        ("update_item", {"item_id": item["id"], "priority": "high"}),
        ("update_event", {"event_id": event["id"], "start": "2026-10-12T11:00"}),
        ("list_events", {"start_date": "2026-10-12", "end_date": "2026-10-12"}),
        ("list_items", {"area": "personal"}),
        ("list_projects", {}),
        ("get_project", {"project_id": project["id"]}),
        ("search", {"query": "Kartons"}),
        ("get_agenda", {"start_date": "2026-10-12", "end_date": "2026-10-18"}),
        ("archive_item", {"item_id": item["id"]}),
        ("delete_event", {"event_id": event["id"]}),
    ]
    for name, payload in calls:
        data, is_error = await _call(session, name, payload)
        assert not is_error, (name, data)

    used = {"create_project", "create_item", "create_event"} | {name for name, _ in calls}
    assert used == {d["name"] for d in tool_definitions()}


async def test_update_item_null_clears_due_date(session):
    item, _ = await _call(session, "create_item", {"type": "todo", "area": "personal", "title": "A", "due_date": "2026-10-10"})
    data, is_error = await _call(session, "update_item", {"item_id": item["id"], "due_date": None})
    assert not is_error
    assert data["due_date"] is None


async def test_update_item_null_title_is_error(session):
    item, _ = await _call(session, "create_item", {"type": "todo", "area": "personal", "title": "A"})
    _, is_error = await _call(session, "update_item", {"item_id": item["id"], "title": None})
    assert is_error


async def test_update_event_null_end_clears_end(session):
    event, _ = await _call(session, "create_event", {"title": "X", "start": "2026-10-12T10:00", "end": "2026-10-12T11:00"})
    data, is_error = await _call(session, "update_event", {"event_id": event["id"], "end": None})
    assert not is_error
    assert data["end_at"] is None


async def test_session_usable_after_domain_error(session):
    await _call(session, "create_item", {"type": "todo", "area": "personal", "title": "Bleibt"})
    _, is_error = await _call(
        session, "create_item", {"type": "idea", "area": "personal", "title": "X", "due_date": "2026-10-10"}
    )
    assert is_error
    data, is_error = await _call(session, "list_items", {})
    assert not is_error
    assert [i["title"] for i in data] == ["Bleibt"]


async def test_search_returns_event_times_in_local_zone(session):
    _, err = await _call(session, "create_event", {"title": "Zahnarzt", "start": "2026-10-12T14:00"})
    assert not err
    data, is_error = await _call(session, "search", {"query": "Zahnarzt"})
    assert not is_error
    assert [e["start_at"] for e in data["events"]] == ["2026-10-12T14:00:00+02:00"]
