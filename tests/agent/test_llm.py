import anthropic
import httpx2
import pytest

from app.agent.llm import AnthropicLLM, LLMError


class _FailingStream:
    def __init__(self, error: Exception) -> None:
        self._error = error

    async def __aenter__(self):
        raise self._error

    async def __aexit__(self, *exc_info) -> None:
        return None


class _FakeClient:
    # fake stream that dies right away with an api error

    def __init__(self, error: Exception) -> None:
        stream = lambda **kwargs: _FailingStream(error)  # noqa: E731
        self.beta = type("Beta", (), {"messages": type("Messages", (), {"stream": staticmethod(stream)})()})()


def _status_error(status: int, body: object) -> anthropic.APIStatusError:
    request = httpx2.Request("POST", "https://api.anthropic.com/v1/messages")
    response = httpx2.Response(status, request=request)
    error_class = anthropic.BadRequestError if status == 400 else anthropic.APIStatusError
    return error_class("Fehler", response=response, body=body)


async def _run(llm: AnthropicLLM) -> None:
    async def on_text(_: str) -> None:
        return None

    await llm.run_turn(system="s", tools=[], messages=[], on_text=on_text)


async def test_api_error_message_is_passed_to_the_user():
    body = {
        "type": "error",
        "error": {"type": "invalid_request_error", "message": "This API key is not scoped to a workspace."},
    }
    llm = AnthropicLLM(_FakeClient(_status_error(400, body)), "claude-sonnet-5-5", "medium")
    with pytest.raises(LLMError) as caught:
        await _run(llm)
    assert str(caught.value) == "Fehler der Claude-API (HTTP 400): This API key is not scoped to a workspace."


async def test_api_error_without_message_keeps_generic_text():
    llm = AnthropicLLM(_FakeClient(_status_error(500, None)), "claude-sonnet-5-5", "medium")
    with pytest.raises(LLMError) as caught:
        await _run(llm)
    assert str(caught.value) == "Fehler der Claude-API (HTTP 500)."
