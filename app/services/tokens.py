import hashlib
import secrets
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.errors import NotFound
from app.models import ApiToken, utcnow


def hash_token(raw: str) -> str:
    return hashlib.sha256(raw.encode()).hexdigest()


async def create_token(session: AsyncSession, name: str) -> tuple[ApiToken, str]:
    raw = secrets.token_urlsafe(32)
    token = ApiToken(name=name, token_hash=hash_token(raw))
    session.add(token)
    await session.commit()
    return token, raw


async def list_tokens(session: AsyncSession) -> list[ApiToken]:
    return list(await session.scalars(select(ApiToken).order_by(ApiToken.created_at)))


async def revoke_token(session: AsyncSession, token_id: uuid.UUID) -> ApiToken:
    token = await session.get(ApiToken, token_id)
    if token is None:
        raise NotFound("Token nicht gefunden")
    token.revoked_at = utcnow()
    await session.commit()
    return token


async def verify_token(session: AsyncSession, raw: str) -> ApiToken | None:
    token = await session.scalar(
        select(ApiToken).where(ApiToken.token_hash == hash_token(raw), ApiToken.revoked_at.is_(None))
    )
    if token is None:
        return None
    token.last_used_at = utcnow()
    await session.commit()
    return token
