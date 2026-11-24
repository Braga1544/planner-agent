import os

import pytest
from anthropic import AsyncAnthropic

from app.agent.tools import tool_definitions

pytestmark = pytest.mark.live


async def test_api_accepts_all_tool_schemas():
    if not os.environ.get("ANTHROPIC_API_KEY"):
        pytest.skip("ANTHROPIC_API_KEY not set")
    client = AsyncAnthropic()
    response = await client.messages.create(
        model="claude-sonnet-5-5",
        max_tokens=1024,
        tools=tool_definitions(),
        messages=[{"role": "user", "content": "Antworte nur mit OK, ohne Tools zu benutzen."}],
    )
    assert response.stop_reason in {"end_turn", "tool_use"}
