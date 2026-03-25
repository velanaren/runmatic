import logging

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import (
    create_access_token,
    get_current_user_id,
    get_password_hash,
    invalidate_session,
    store_session,
    verify_password,
)
from app.database import get_db
from app.models import User
from app.schemas import LoginRequest, TokenResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/auth", tags=["auth"])
security = HTTPBearer()


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)) -> TokenResponse:
    result = await db.execute(select(User).where(User.email == payload.email))
    user = result.scalar_one_or_none()

    if user is None or not verify_password(payload.password, user.hashed_password):
        logger.warning("Failed login attempt", extra={"email": payload.email})
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    token = create_access_token(user.id, user.email)
    await store_session(user.id, token)

    logger.info("User logged in", extra={"user_id": user.id, "email": user.email})
    return TokenResponse(access_token=token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
async def logout(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> None:
    user_id = await get_current_user_id(credentials.credentials)
    if user_id is not None:
        await invalidate_session(user_id)
        logger.info("User logged out", extra={"user_id": user_id})


async def require_auth(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> int:
    user_id = await get_current_user_id(credentials.credentials)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user_id
