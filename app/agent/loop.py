import sys
from collections.abc import Awaitable, Callable
from datetime import datetime
from typing import Any
from uuid import UUID
from zoneinfo import ZoneInfo

from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.llm import LLM, LLMError
from app.agent.prompt import SYSTEM_PROMPT, now_prefix
from app.agent.tools import ToolContext, run_tool, tool_definitions
from app.services import conversations

MAX_TOOL_ROUNDS = 10
REFUSAL_TEXT = "Diese Anfrage wurde vom Modell abgelehnt. Formuliere sie bitte anders."
TRUNCATED_TEXT = "⚠️ Die Antwort wurde abgeschnitten (Token-Limit). Bitte frag noch einmal oder teile die Anfrage auf."
UNCLEAR_TEXT = "Abgebrochen, Ausführung unklar – bitte Stand prüfen."
ROUND_LIMIT_TEXT = "⚠️ Abgebrochen: zu viele Tool-Schritte in einer Anfrage."

Emit = Callable[[str, dict[str, Any]], Awaitable[None]]


def _tool_result(tool_use_id: str, content: str, is_error: bool) -> dict[str, Any]:
    block: dict[str, Any] = {"type": "tool_result", "tool_use_id": tool_use_id, "content": content}
    if is_error:
        block["is_error"] = True
    return block


def _add_usage(total: dict[str, int], usage: dict[str, Any]) -> None:
    for key, value in usage.items():
        if isinstance(value, int) and not isinstance(value, bool):
            total[key] = total.get(key, 0) + value


async def _close_tool_uses(
    session: AsyncSession, conversation_id: UUID, tool_uses: list[dict[str, Any]], reason: str
) -> None:
    # every tool_use needs a tool_result or the api rejects the convo
    if tool_uses:
        await conversations.append_message(
            session, conversation_id, "user", [_tool_result(b["id"], reason, True) for b in tool_uses]
        )


async def _execute_tools(
    session: AsyncSession, ctx: ToolContext, conversation_id: UUID, tool_uses: list[dict[str, Any]], emit: Emit
) -> None:
    results: dict[str, dict[str, Any]] = {}
    in_flight: str | None = None
    try:
        for block in tool_uses:
            await emit("tool_start", {"name": block["name"], "id": block["id"]})
            in_flight = block["id"]
            content, is_error = await run_tool(session, ctx, block["name"], block.get("input") or {})
            in_flight = None
            results[block["id"]] = _tool_result(block["id"], content, is_error)
            await emit("tool_end", {"name": block["name"], "id": block["id"], "is_error": is_error})
    finally:
        # even on cancel, all results go into ONE user msg
        if sys.exc_info()[0] is not None:
            await session.rollback()  # drop the half-done tx before writing history
        blocks = [
            results.get(b["id"])
            or _tool_result(
                b["id"],
                UNCLEAR_TEXT if b["id"] == in_flight else "Abgebrochen, das Tool wurde nicht ausgeführt.",
                True,
            )
            for b in tool_uses
        ]
        await conversations.append_message(session, conversation_id, "user", blocks)


async def run_agent(
    *,
    session: AsyncSession,
    conversation_id: UUID,
    user_text: str,
    llm: LLM,
    now: datetime,
    tz: ZoneInfo,
    emit: Emit,
) -> None:
    ctx = ToolContext(tz=tz, now=now)
    # repair dangling tool_use after a hard abort, otherwise the chat is dead
    stored = await conversations.list_messages(session, conversation_id)
    if stored and stored[-1].role == "assistant":
        open_uses = [b for b in stored[-1].content if b.get("type") == "tool_use"]
        await _close_tool_uses(session, conversation_id, open_uses, UNCLEAR_TEXT)
    await conversations.append_message(
        session,
        conversation_id,
        "user",
        [{"type": "text", "text": now_prefix(now.astimezone(tz))}, {"type": "text", "text": user_text}],
    )
    await conversations.set_title_if_missing(session, conversation_id, user_text)

    tools = tool_definitions()
    total_usage: dict[str, int] = {}
    last_assistant_id: UUID | None = None

    async def on_text(delta: str) -> None:
        await emit("text", {"delta": delta})

    for round_no in range(MAX_TOOL_ROUNDS + 1):
        history = await conversations.history(session, conversation_id)
        try:
            turn = await llm.run_turn(system=SYSTEM_PROMPT, tools=tools, messages=history, on_text=on_text)
        except LLMError as exc:
            await emit("error", {"detail": str(exc)})
            return
        _add_usage(total_usage, turn.usage)
        if turn.content:
            message = await conversations.append_message(
                session, conversation_id, "assistant", turn.content, turn.usage
            )
            last_assistant_id = message.id
        tool_uses = [b for b in turn.content if b.get("type") == "tool_use"]

        if turn.stop_reason == "refusal":
            await _close_tool_uses(session, conversation_id, tool_uses, "Nicht ausgeführt: Anfrage abgelehnt.")
            await emit("text", {"delta": REFUSAL_TEXT})
            break
        if turn.stop_reason == "max_tokens":
            await _close_tool_uses(session, conversation_id, tool_uses, "Nicht ausgeführt: Antwort abgeschnitten.")
            await emit("text", {"delta": TRUNCATED_TEXT})
            break
        if not tool_uses:
            break
        if turn.stop_reason != "tool_use":
            await _close_tool_uses(
                session, conversation_id, tool_uses, "Nicht ausgeführt: unerwartetes Ende der Antwort."
            )
            break
        if round_no == MAX_TOOL_ROUNDS:
            await _close_tool_uses(session, conversation_id, tool_uses, "Nicht ausgeführt: Limit für Tool-Schritte.")
            await emit("text", {"delta": ROUND_LIMIT_TEXT})
            break
        await _execute_tools(session, ctx, conversation_id, tool_uses, emit)

    await emit("done", {"message_id": str(last_assistant_id) if last_assistant_id else None, "usage": total_usage})
