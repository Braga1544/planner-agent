import asyncio
import json
import logging
import uuid
from collections import defaultdict
from datetime import datetime
from typing import Any

from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.agent.llm import LLM, get_llm
from app.agent.loop import run_agent
from app.clock import get_now
from app.config import Settings, get_settings
from app.db import get_session, get_session_factory
from app.errors import Conflict
from app.schemas.chat import ChatRequest, ConversationOut, MessageOut
from app.services import conversations

KEEPALIVE_SECONDS = 15  # below proxy/ios idle timeouts (60s)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/conversations", tags=["chat"])

# single instance, in-process lock is enough
_locks: defaultdict[uuid.UUID, asyncio.Lock] = defaultdict(asyncio.Lock)
# keep refs or the gc eats the tasks
_tasks: set[asyncio.Task] = set()


PING = ": ping\n\n"  # sse comment as keepalive


def sse(kind: str, data: dict[str, Any]) -> str:
    return f"event: {kind}\ndata: {json.dumps(data, ensure_ascii=False)}\n\n"


@router.post("", response_model=ConversationOut, status_code=201)
async def create_conversation(session: AsyncSession = Depends(get_session)):
    return await conversations.create_conversation(session)


@router.get("", response_model=list[ConversationOut])
async def list_conversations(session: AsyncSession = Depends(get_session)):
    return await conversations.list_conversations(session)


@router.get("/{conversation_id}/messages", response_model=list[MessageOut])
async def list_messages(conversation_id: uuid.UUID, session: AsyncSession = Depends(get_session)):
    await conversations.get_conversation(session, conversation_id)
    return await conversations.list_messages(session, conversation_id)


@router.post("/{conversation_id}/messages")
async def post_message(
    conversation_id: uuid.UUID,
    body: ChatRequest,
    session: AsyncSession = Depends(get_session),
    session_factory: async_sessionmaker[AsyncSession] = Depends(get_session_factory),
    llm: LLM = Depends(get_llm),
    now: datetime = Depends(get_now),
    settings: Settings = Depends(get_settings),
) -> StreamingResponse:
    await conversations.get_conversation(session, conversation_id)
    lock = _locks[conversation_id]
    if lock.locked():
        raise Conflict("In diesem Chat läuft bereits eine Anfrage")

    queue: asyncio.Queue[tuple[str, dict[str, Any]] | None] = asyncio.Queue()

    async def emit(kind: str, data: dict[str, Any]) -> None:
        await queue.put((kind, data))

    async def worker() -> None:
        # keeps running even if the client is gone
        async with lock:
            try:
                async with session_factory() as agent_session:
                    await run_agent(
                        session=agent_session,
                        conversation_id=conversation_id,
                        user_text=body.text,
                        llm=llm,
                        now=now,
                        tz=settings.tz,
                        emit=emit,
                    )
            except Exception:
                logger.exception("agent run failed for chat %s", conversation_id)
                await emit("error", {"detail": "Interner Fehler"})
            finally:
                await queue.put(None)

    task = asyncio.create_task(worker())
    _tasks.add(task)
    task.add_done_callback(_tasks.discard)

    async def stream():
        while True:
            try:
                item = await asyncio.wait_for(queue.get(), timeout=KEEPALIVE_SECONDS)
            except asyncio.TimeoutError:
                yield PING
                continue
            if item is None:
                return
            yield sse(*item)

    return StreamingResponse(
        stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
