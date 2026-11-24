from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Any, Protocol

import anthropic
from fastapi import Depends

from app.config import Settings, get_settings

FALLBACK_BETA = "server-side-fallback-2026-07-01"
MAX_TOKENS = 16000

OnText = Callable[[str], Awaitable[None]]


class LLMError(Exception):
    pass


@dataclass
class TurnResult:
    content: list[dict[str, Any]]
    stop_reason: str | None
    usage: dict[str, Any] = field(default_factory=dict)


class LLM(Protocol):
    async def run_turn(
        self,
        *,
        system: str,
        tools: list[dict[str, Any]],
        messages: list[dict[str, Any]],
        on_text: OnText,
    ) -> TurnResult: ...


class AnthropicLLM:
    def __init__(self, client: anthropic.AsyncAnthropic, model: str, effort: str) -> None:
        self._client = client
        self._model = model
        self._effort = effort

    async def run_turn(self, *, system, tools, messages, on_text) -> TurnResult:
        try:
            async with self._client.beta.messages.stream(
                model=self._model,
                max_tokens=MAX_TOKENS,
                system=[{"type": "text", "text": system, "cache_control": {"type": "ephemeral"}}],
                tools=tools,
                messages=messages,
                thinking={"type": "adaptive"},
                output_config={"effort": self._effort},
                cache_control={"type": "ephemeral"},
                betas=[FALLBACK_BETA],
                fallbacks="default",
            ) as stream:
                async for event in stream:
                    if event.type == "text":
                        await on_text(event.text)
                message = await stream.get_final_message()
        except anthropic.RateLimitError as exc:
            raise LLMError("Die Claude-API ist gerade ausgelastet (Rate-Limit). Bitte gleich nochmal versuchen.") from exc
        except anthropic.APIConnectionError as exc:
            raise LLMError("Keine Verbindung zur Claude-API.") from exc
        except anthropic.APIStatusError as exc:
            detail = _api_error_detail(exc.body)
            suffix = f": {detail}" if detail else "."
            raise LLMError(f"Fehler der Claude-API (HTTP {exc.status_code}){suffix}") from exc
        return TurnResult(
            content=[block.to_dict(mode="json") for block in message.content],
            stop_reason=message.stop_reason,
            usage=message.usage.to_dict(mode="json"),
        )


def _api_error_detail(body: object) -> str | None:
    # api sends {"type": "error", ...}, pass the message through
    if isinstance(body, dict):
        error = body.get("error")
        if isinstance(error, dict) and isinstance(error.get("message"), str):
            return error["message"]
    return None


@lru_cache
def _client(api_key: str) -> anthropic.AsyncAnthropic:
    return anthropic.AsyncAnthropic(api_key=api_key)


def get_llm(settings: Settings = Depends(get_settings)) -> LLM:
    return AnthropicLLM(_client(settings.anthropic_api_key), settings.claude_model, settings.claude_effort)
