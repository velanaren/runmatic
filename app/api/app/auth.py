import logging
from datetime import datetime, timedelta, timezone

import redis.asyncio as aioredis
from jose import JWTError, jwt
from passlib.context import CryptContext

from app.config import settings

logger = logging.getLogger(__name__)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

_redis_client: aioredis.Redis | None = None


def get_redis() -> aioredis.Redis:
    global _redis_client
    if _redis_client is None:
        _redis_client = aioredis.from_url(
            settings.redis_url,
            encoding="utf-8",
            decode_responses=True,
        )
    return _redis_client


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(user_id: int, email: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_expire_minutes)
    payload = {
        "sub": str(user_id),
        "email": email,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.secret_key, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict:
    return jwt.decode(token, settings.secret_key, algorithms=[settings.jwt_algorithm])


async def store_session(user_id: int, token: str) -> None:
    redis = get_redis()
    session_key = f"session:{user_id}"
    await redis.setex(session_key, settings.session_ttl_seconds, token)
    logger.debug("Session stored", extra={"user_id": user_id})


async def invalidate_session(user_id: int) -> None:
    redis = get_redis()
    session_key = f"session:{user_id}"
    await redis.delete(session_key)
    logger.debug("Session invalidated", extra={"user_id": user_id})


async def validate_session(user_id: int, token: str) -> bool:
    redis = get_redis()
    session_key = f"session:{user_id}"
    stored_token = await redis.get(session_key)
    return stored_token == token


async def get_current_user_id(token: str) -> int | None:
    try:
        payload = decode_token(token)
        user_id = int(payload["sub"])
        is_valid = await validate_session(user_id, token)
        if not is_valid:
            logger.warning("Session not found in Redis", extra={"user_id": user_id})
            return None
        return user_id
    except (JWTError, KeyError, ValueError) as exc:
        logger.warning("Token validation failed", extra={"error": str(exc)})
        return None
