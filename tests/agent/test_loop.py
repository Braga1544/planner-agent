import asyncio
from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

import app.agent.loop as loop_module
from app.agent.llm import LLMError, TurnResult
from app.agent.loop import MAX_TOOL_ROUNDS, REFUSAL_TEXT, ROUND_LIMIT_TEXT, TRUNCATED_TEXT, run_agent
from app.agent.prompt import SYSTEM_PROMPT
from app.agent.tools import tool_definitions
from app.services import conversations
from app.services import items as item_service
from tests.agent.fake_llm import FakeLLM, text_turn, tool_turn

TZ = ZoneInfo("Europe/Berlin")
NOW = datetime(2026, 10, 9, 20, 11, tzinfo=TZ)
TODO = {"type": "todo", "area": "personal", "title": "Milch kaufen"}


class Recorder:
    def __init__(self) -> None:
        self.events: list[tuple[str, dict]] = []

    async def __call__(self, kind: str, data: dict) -> None:
        self.events.append((kind, data))

    @property
    def kinds(self) -> list[str]:
        return [k for k, _ in self.events]


async def _run(session, llm, text="Hallo", conversation=None):
    emit = Recorder()
    conv = conversation or await conversations.create_conversation(session)
    await run_agent(session=session, conversation_id=conv.id, user_text=text, llm=llm, now=NOW, tz=TZ, emit=emit)
    return conv, emit


async def _stored(session, conv):
    return [(m.role, m.content) for m in await conversations.list_messages(session, conv.id)]


async def test_plain_answer_is_streamed_and_stored(session):
    llm = FakeLLM([text_turn("Heute steht nichts an.")])
    conv, emit = await _run(session, llm, "Was steht an?")

    assert emit.kinds == ["text", "done"]
    assert emit.events[0][1] == {"delta": "Heute steht nichts an."}
    assert emit.events[1][1]["usage"] == {"input_tokens": 10, "output_tokens": 5}
    stored = await _stored(session, conv)
    assert stored[0] == (
        "user",
        [
            {"type": "text", "text": "[Jetzt: Fr, 09.10.2026 20:11 Europe/Berlin]"},
            {"type": "text", "text": "Was steht an?"},
        ],
    )
    assert stored[1] == ("assistant", [{"type": "text", "text": "Heute steht nichts an."}])
    assert (await conversations.get_conversation(session, conv.id)).title == "Was steht an?"
    assert llm.calls[0]["system"] == SYSTEM_PROMPT
    assert llm.calls[0]["tools"] == tool_definitions()


async def test_tool_round_executes_and_feeds_result_back(session):
    llm = FakeLLM([tool_turn(("create_item", TODO)), text_turn("✓ ToDo angelegt")])
    conv, emit = await _run(session, llm, "Erinnere mich an Milch")

    assert emit.kinds == ["tool_start", "tool_end", "text", "done"]
    assert emit.events[1][1]["is_error"] is False
    assert [i.title for i in await item_service.list_items(session)] == ["Milch kaufen"]
    assert [role for role, _ in await _stored(session, conv)] == ["user", "assistant", "user", "assistant"]

    second = llm.calls[1]["messages"]
    result = second[2]["content"][0]
    assert result["type"] == "tool_result"
    assert result["tool_use_id"] == second[1]["content"][0]["id"]
    assert "is_error" not in result


async def test_tool_error_is_marked(session):
    bad = {"type": "idea", "area": "personal", "title": "X", "due_date": "2026-10-10"}
    llm = FakeLLM([tool_turn(("create_item", bad)), text_turn("Geht so nicht.")])
    conv, emit = await _run(session, llm)

    assert emit.events[1] == ("tool_end", {"name": "create_item", "id": emit.events[0][1]["id"], "is_error": True})
    result = (await _stored(session, conv))[2][1][0]
    assert result["is_error"] is True


async def test_refusal_shows_message(session):
    llm = FakeLLM([TurnResult(content=[], stop_reason="refusal", usage={})])
    conv, emit = await _run(session, llm)
    assert emit.events[0] == ("text", {"delta": REFUSAL_TEXT})
    assert emit.kinds[-1] == "done"
    assert [role for role, _ in await _stored(session, conv)] == ["user"]


async def test_max_tokens_does_not_run_truncated_tool(session):
    turn = tool_turn(("create_item", TODO))
    turn.stop_reason = "max_tokens"
    conv, emit = await _run(session, FakeLLM([turn]))

    assert await item_service.list_items(session) == []
    assert emit.events[0] == ("text", {"delta": TRUNCATED_TEXT})
    role, blocks = (await _stored(session, conv))[-1]
    assert role == "user" and blocks[0]["is_error"] is True


async def test_round_limit_stops_loop(session):
    llm = FakeLLM([tool_turn(("list_projects", {})) for _ in range(MAX_TOOL_ROUNDS + 1)])
    conv, emit = await _run(session, llm)

    assert emit.kinds.count("tool_end") == MAX_TOOL_ROUNDS
    assert ("text", {"delta": ROUND_LIMIT_TEXT}) in emit.events
    assert len(llm.calls) == MAX_TOOL_ROUNDS + 1
    role, blocks = (await _stored(session, conv))[-1]
    assert role == "user" and blocks[0]["is_error"] is True


async def test_llm_error_emits_error_and_keeps_user_message(session):
    conv, emit = await _run(session, FakeLLM([LLMError("Keine Verbindung zur Claude-API.")]))
    assert emit.events == [("error", {"detail": "Keine Verbindung zur Claude-API."})]
    assert [role for role, _ in await _stored(session, conv)] == ["user"]


async def test_cancellation_mid_round_keeps_history_valid(session, monkeypatch):
    async def cancelling_run_tool(session, ctx, name, raw_input):
        raise asyncio.CancelledError

    monkeypatch.setattr(loop_module, "run_tool", cancelling_run_tool)
    llm = FakeLLM([tool_turn(("list_projects", {}), ("search", {"query": "x"}))])
    conv = await conversations.create_conversation(session)

    with pytest.raises(asyncio.CancelledError):
        await run_agent(
            session=session, conversation_id=conv.id, user_text="Hallo", llm=llm, now=NOW, tz=TZ, emit=Recorder()
        )

    role, blocks = (await _stored(session, conv))[-1]
    assert role == "user"
    assert len(blocks) == 2
    assert all(b["type"] == "tool_result" and b["is_error"] for b in blocks)


async def test_history_is_append_only_across_messages(session):
    llm = FakeLLM([text_turn("Erste Antwort"), text_turn("Zweite Antwort")])
    conv, _ = await _run(session, llm, "Erste Frage")
    await _run(session, llm, "Zweite Frage", conversation=conv)

    first, second = llm.calls[0]["messages"], llm.calls[1]["messages"]
    assert second[: len(first)] == first
    assert second[len(first)] == {"role": "assistant", "content": [{"type": "text", "text": "Erste Antwort"}]}


async def test_unexpected_stop_reason_closes_tool_uses(session):
    turn = tool_turn(("create_item", TODO))
    turn.stop_reason = "model_context_window_exceeded"
    conv, emit = await _run(session, FakeLLM([turn]))

    assert await item_service.list_items(session) == []
    assert emit.kinds[-1] == "done"
    role, blocks = (await _stored(session, conv))[-1]
    assert role == "user" and blocks[0]["type"] == "tool_result" and blocks[0]["is_error"] is True


async def test_open_tool_use_from_crash_is_repaired_on_next_run(session):
    conv = await conversations.create_conversation(session)
    await conversations.append_message(session, conv.id, "user", [{"type": "text", "text": "Hi"}])
    await conversations.append_message(
        session, conv.id, "assistant", [{"type": "tool_use", "id": "toolu_crash", "name": "list_projects", "input": {}}]
    )
    llm = FakeLLM([text_turn("Weiter")])
    await _run(session, llm, "Und jetzt?", conversation=conv)

    sent = llm.calls[0]["messages"]
    assert sent[2]["role"] == "user"
    assert sent[2]["content"][0]["tool_use_id"] == "toolu_crash"
    assert sent[2]["content"][0]["is_error"] is True
    assert sent[3]["content"][1] == {"type": "text", "text": "Und jetzt?"}
