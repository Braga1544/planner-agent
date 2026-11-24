import copy
import uuid
from typing import Any

from app.agent.llm import TurnResult


class FakeLLM:
    def __init__(self, turns: list[TurnResult | Exception]) -> None:
        self.turns = list(turns)
        self.calls: list[dict[str, Any]] = []

    async def run_turn(self, *, system, tools, messages, on_text) -> TurnResult:
        self.calls.append({"system": system, "tools": tools, "messages": copy.deepcopy(messages)})
        turn = self.turns.pop(0)
        if isinstance(turn, Exception):
            raise turn
        for block in turn.content:
            if block.get("type") == "text":
                await on_text(block["text"])
        return turn


def text_turn(text: str) -> TurnResult:
    return TurnResult(
        content=[{"type": "text", "text": text}],
        stop_reason="end_turn",
        usage={"input_tokens": 10, "output_tokens": 5},
    )


def tool_turn(*calls: tuple[str, dict[str, Any]]) -> TurnResult:
    content = [
        {"type": "tool_use", "id": f"toolu_{uuid.uuid4().hex[:12]}", "name": name, "input": payload}
        for name, payload in calls
    ]
    return TurnResult(content=content, stop_reason="tool_use", usage={"input_tokens": 10, "output_tokens": 5})
