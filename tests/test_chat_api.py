import asyncio
import uuid

import pytest

import app.api.chat as chat_module
from app.agent.llm import get_llm
from tests.agent.fake_llm import FakeLLM, text_turn
from tests.helpers import parse_sse


@pytest.fixture
def fake_llm(app):
    llm = FakeLLM([])
    app.dependency_overrides[get_llm] = lambda: llm
    return llm


async def _conversation(client) -> dict:
    resp = await client.post("/api/v1/conversations")
    assert resp.status_code == 201
    return resp.json()


async def test_create_and_list_conversations(client):
    conv = await _conversation(client)
    listed = (await client.get("/api/v1/conversations")).json()
    assert [c["id"] for c in listed] == [conv["id"]]
    assert listed[0]["title"] is None


async def test_post_message_streams_sse(client, fake_llm):
    fake_llm.turns.append(text_turn("Hallo!"))
    conv = await _conversation(client)

    resp = await client.post(f"/api/v1/conversations/{conv['id']}/messages", json={"text": "Hi"})
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/event-stream")
    assert resp.headers["cache-control"] == "no-cache"
    assert resp.headers["x-accel-buffering"] == "no"
    events = parse_sse(resp.text)
    assert [kind for kind, _ in events] == ["text", "done"]
    assert events[0][1] == {"delta": "Hallo!"}

    messages = (await client.get(f"/api/v1/conversations/{conv['id']}/messages")).json()
    assert [(m["seq"], m["role"]) for m in messages] == [(1, "user"), (2, "assistant")]
    assert messages[0]["content"][0]["text"] == "[Jetzt: Fr, 09.10.2026 20:11 Europe/Berlin]"
    assert (await client.get("/api/v1/conversations")).json()[0]["title"] == "Hi"


async def test_unknown_conversation_is_404(client, fake_llm):
    resp = await client.post(f"/api/v1/conversations/{uuid.uuid4()}/messages", json={"text": "Hi"})
    assert resp.status_code == 404
    assert resp.json() == {"detail": "Chat nicht gefunden"}


async def test_concurrent_request_is_409(client, fake_llm):
    conv = await _conversation(client)
    lock = chat_module._locks[uuid.UUID(conv["id"])]
    await lock.acquire()
    try:
        resp = await client.post(f"/api/v1/conversations/{conv['id']}/messages", json={"text": "Hi"})
    finally:
        lock.release()
    assert resp.status_code == 409
    assert resp.json() == {"detail": "In diesem Chat läuft bereits eine Anfrage"}


async def test_empty_text_rejected(client, fake_llm):
    conv = await _conversation(client)
    resp = await client.post(f"/api/v1/conversations/{conv['id']}/messages", json={"text": ""})
    assert resp.status_code == 422


async def test_chat_requires_auth(anon_client):
    assert (await anon_client.post("/api/v1/conversations")).status_code == 401


async def test_agent_crash_emits_error(client, fake_llm, monkeypatch):
    async def crash(**kwargs):
        raise RuntimeError("kaputt")

    monkeypatch.setattr(chat_module, "run_agent", crash)
    conv = await _conversation(client)
    resp = await client.post(f"/api/v1/conversations/{conv['id']}/messages", json={"text": "Hi"})
    assert parse_sse(resp.text) == [("error", {"detail": "Interner Fehler"})]


async def test_whitespace_only_text_rejected(client, fake_llm):
    conv = await _conversation(client)
    for text in ("   ", "\n", " \t\n "):
        resp = await client.post(f"/api/v1/conversations/{conv['id']}/messages", json={"text": text})
        assert resp.status_code == 422


async def test_keepalive_ping_is_sent_and_ignored_by_parser(client, app, monkeypatch):
    class SlowLLM(FakeLLM):
        async def run_turn(self, **kwargs):
            await asyncio.sleep(0.15)
            return await super().run_turn(**kwargs)

    llm = SlowLLM([text_turn("Hallo!")])
    app.dependency_overrides[get_llm] = lambda: llm
    monkeypatch.setattr(chat_module, "KEEPALIVE_SECONDS", 0.02)
    conv = await _conversation(client)
    resp = await client.post(f"/api/v1/conversations/{conv['id']}/messages", json={"text": "Hi"})
    assert ": ping" in resp.text
    assert [kind for kind, _ in parse_sse(resp.text)] == ["text", "done"]


async def test_agent_run_survives_stream_close(app, session, fake_llm, settings):
    from app.clock import get_now
    from app.db import get_session_factory
    from app.models import Conversation
    from app.services import conversations
    from tests.conftest import NOW

    fake_llm.turns.append(text_turn("Hallo!"))
    conv = await conversations.create_conversation(session)
    factory = app.dependency_overrides[get_session_factory]()
    response = await chat_module.post_message(
        conversation_id=conv.id,
        body=chat_module.ChatRequest(text="Hi"),
        session=session,
        session_factory=factory,
        llm=fake_llm,
        now=NOW,
        settings=settings,
    )
    stream = response.body_iterator
    first = await stream.__anext__()
    assert first.startswith("event: text")
    await stream.aclose()  # client disconnects after the first event

    await asyncio.gather(*chat_module._tasks)
    messages = await conversations.list_messages(session, conv.id)
    assert [m.role for m in messages] == ["user", "assistant"]
    assert messages[1].content[0]["text"] == "Hallo!"
    assert not chat_module._locks[conv.id].locked()


async def test_lock_is_released_after_run(client, fake_llm):
    fake_llm.turns.extend([text_turn("Eins"), text_turn("Zwei")])
    conv = await _conversation(client)
    url = f"/api/v1/conversations/{conv['id']}/messages"
    assert (await client.post(url, json={"text": "a"})).status_code == 200
    resp = await client.post(url, json={"text": "b"})
    assert resp.status_code == 200
    assert [k for k, _ in parse_sse(resp.text)] == ["text", "done"]
