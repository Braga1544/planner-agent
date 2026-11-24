import uuid
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import NotFound
from app.models import Conversation, Message, utcnow


async def create_conversation(session: AsyncSession) -> Conversation:
    conversation = Conversation()
    session.add(conversation)
    await session.commit()
    return conversation


async def get_conversation(session: AsyncSession, conversation_id: uuid.UUID) -> Conversation:
    conversation = await session.get(Conversation, conversation_id)
    if conversation is None:
        raise NotFound("Chat nicht gefunden")
    return conversation


async def list_conversations(session: AsyncSession, limit: int = 50) -> list[Conversation]:
    stmt = select(Conversation).order_by(Conversation.updated_at.desc()).limit(limit)
    return list(await session.scalars(stmt))


async def list_messages(session: AsyncSession, conversation_id: uuid.UUID) -> list[Message]:
    stmt = select(Message).where(Message.conversation_id == conversation_id).order_by(Message.seq)
    return list(await session.scalars(stmt))


async def history(session: AsyncSession, conversation_id: uuid.UUID) -> list[dict[str, Any]]:
    result = []
    for m in await list_messages(session, conversation_id):
        # api doesn't like empty text blocks
        blocks = [
            b for b in m.content if not (b.get("type") == "text" and not str(b.get("text", "")).strip())
        ]
        if blocks:
            result.append({"role": m.role, "content": blocks})
    return result


async def append_message(
    session: AsyncSession,
    conversation_id: uuid.UUID,
    role: str,
    content: list[dict[str, Any]],
    usage: dict[str, Any] | None = None,
) -> Message:
    conversation = await get_conversation(session, conversation_id)
    last_seq = await session.scalar(select(func.max(Message.seq)).where(Message.conversation_id == conversation_id))
    message = Message(conversation_id=conversation_id, seq=(last_seq or 0) + 1, role=role, content=content, usage=usage)
    conversation.updated_at = utcnow()
    session.add(message)
    await session.commit()
    return message


async def set_title_if_missing(session: AsyncSession, conversation_id: uuid.UUID, text: str) -> None:
    conversation = await get_conversation(session, conversation_id)
    if conversation.title is None and text.strip():
        conversation.title = text.strip().splitlines()[0][:60]
        await session.commit()
