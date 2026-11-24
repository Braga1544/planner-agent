import json
import os

import pytest
from anthropic import AsyncAnthropic

from app.agent.llm import AnthropicLLM
from app.agent.prompt import SYSTEM_PROMPT
from app.agent.tools import tool_definitions

pytestmark = pytest.mark.live


async def test_anthropic_llm_round_trip_with_tools():
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        pytest.skip("ANTHROPIC_API_KEY not set")
    llm = AnthropicLLM(AsyncAnthropic(api_key=key), "claude-sonnet-5-5", "low")
    texts: list[str] = []

    async def on_text(delta: str) -> None:
        texts.append(delta)

    turn = await llm.run_turn(
        system=SYSTEM_PROMPT,
        tools=tool_definitions(),
        messages=[
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": "[Jetzt: Fr, 09.10.2026 20:11 Europe/Berlin]"},
                    {"type": "text", "text": "Was steht heute an?"},
                ],
            }
        ],
        on_text=on_text,
    )
    assert turn.stop_reason == "tool_use"
    assert any(b["type"] == "tool_use" and b["name"] == "get_agenda" for b in turn.content)
    json.dumps(turn.content)  # has to be storable as jsonb
    assert "output_tokens" in turn.usage
