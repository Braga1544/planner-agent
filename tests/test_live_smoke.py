import os

import pytest
from anthropic import AsyncAnthropic

from app.agent.llm import AnthropicLLM, get_llm
from tests.helpers import parse_sse

pytestmark = pytest.mark.live


async def test_agent_end_to_end_with_real_model(client, app):
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        pytest.skip("ANTHROPIC_API_KEY not set")
    llm = AnthropicLLM(AsyncAnthropic(api_key=key), "claude-sonnet-5-5", "medium")
    app.dependency_overrides[get_llm] = lambda: llm

    conv = (await client.post("/api/v1/conversations")).json()
    url = f"/api/v1/conversations/{conv['id']}/messages"

    first = parse_sse((await client.post(url, json={"text": "Leg im Bereich Privat ein ToDo an: Milch kaufen, fällig morgen."}, timeout=180)).text)
    assert "error" not in [kind for kind, _ in first]
    items = (await client.get("/api/v1/items", params={"area": "personal"})).json()
    assert any("milch" in i["title"].lower() and i["due_date"] == "2026-10-10" for i in items)

    second = parse_sse((await client.post(url, json={"text": "Was steht morgen an?"}, timeout=180)).text)
    answer = "".join(data["delta"] for kind, data in second if kind == "text")
    assert "milch" in answer.lower()
