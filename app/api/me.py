from fastapi import APIRouter, Depends

from app.auth import require_token
from app.models import ApiToken

router = APIRouter(tags=["auth"])


@router.get("/me")
async def me(token: ApiToken = Depends(require_token)) -> dict[str, str]:
    return {"token_name": token.name}
