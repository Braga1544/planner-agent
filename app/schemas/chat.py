from datetime import datetime
from typing import Annotated, Any
from uuid import UUID

from pydantic import StringConstraints

from app.schemas.common import InputModel, ORMModel


class ConversationOut(ORMModel):
    id: UUID
    title: str | None
    created_at: datetime
    updated_at: datetime


class MessageOut(ORMModel):
    id: UUID
    seq: int
    role: str
    content: list[dict[str, Any]]
    usage: dict[str, Any] | None
    created_at: datetime


class ChatRequest(InputModel):
    text: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=20000)]
