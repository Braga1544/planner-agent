from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.models import ApiToken
from app.services.tokens import verify_token

_bearer = HTTPBearer(auto_error=False)


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED, detail=detail, headers={"WWW-Authenticate": "Bearer"}
    )


async def require_token(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer),
    session: AsyncSession = Depends(get_session),
) -> ApiToken:
    if credentials is None:
        raise _unauthorized("Nicht authentifiziert")
    token = await verify_token(session, credentials.credentials)
    if token is None:
        raise _unauthorized("Ungültiger oder gesperrter Token")
    return token
