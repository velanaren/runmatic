import logging
import signal
import sys
from contextlib import asynccontextmanager
from typing import Any

import redis.asyncio as aioredis
from alembic import command
from alembic.config import Config
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text

from app.config import settings
from app.database import engine
from app.logging_config import configure_logging
from app.metrics import MetricsMiddleware, metrics_response
from app.routers import action_items, auth, incidents, runbooks, services, webhooks
from app.schemas import DashboardStats, HealthResponse

configure_logging(settings.log_level)
logger = logging.getLogger(__name__)


def run_migrations() -> None:
    """Run Alembic migrations synchronously. Must be called from a thread,
    not directly from an async context, because env.py uses asyncio.run()."""
    logger.info("Running Alembic migrations")
    cfg = Config("alembic.ini")
    command.upgrade(cfg, "head")
    logger.info("Migrations complete")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup — run migrations in a thread executor so asyncio.run() inside
    # env.py doesn't conflict with uvicorn's already-running event loop
    import asyncio

    loop = asyncio.get_event_loop()
    try:
        await loop.run_in_executor(None, run_migrations)
    except Exception as exc:
        # Log and continue — API starts in degraded mode if DB is unavailable.
        # Health endpoint will report db: disconnected. This allows the container
        # to pass liveness checks and wait for the database to become ready.
        logger.warning(
            "Migrations skipped — database unavailable at startup",
            extra={"error": str(exc)},
        )

    logger.info(
        "Runmatic API starting",
        extra={"environment": settings.environment, "log_level": settings.log_level},
    )

    yield

    # Shutdown
    logger.info("Runmatic API shutting down")
    await engine.dispose()
    logger.info("Database connections closed")


app = FastAPI(
    title="Runmatic API",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    openapi_url="/api/openapi.json",
    lifespan=lifespan,
)

app.add_middleware(MetricsMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routers
app.include_router(auth.router)
app.include_router(services.router)
app.include_router(runbooks.router)
app.include_router(incidents.router)
app.include_router(action_items.router)
app.include_router(webhooks.router)


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------


@app.get("/health", response_model=HealthResponse, tags=["observability"])
async def health_check() -> HealthResponse:
    db_status = "disconnected"
    cache_status = "disconnected"
    details: dict[str, Any] = {}

    # Check database
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        db_status = "connected"
    except Exception as exc:
        details["db_error"] = str(exc)
        logger.error("Health check: DB connection failed", extra={"error": str(exc)})

    # Check Redis
    try:
        redis = aioredis.from_url(settings.redis_url, socket_connect_timeout=2)
        await redis.ping()
        await redis.aclose()
        cache_status = "connected"
    except Exception as exc:
        details["cache_error"] = str(exc)
        logger.error("Health check: Redis connection failed", extra={"error": str(exc)})

    overall = "healthy" if db_status == "connected" and cache_status == "connected" else "degraded"

    return HealthResponse(
        status=overall,
        db=db_status,
        cache=cache_status,
        details=details,
    )


# ---------------------------------------------------------------------------
# Metrics
# ---------------------------------------------------------------------------


@app.get("/metrics", tags=["observability"], include_in_schema=False)
async def prometheus_metrics():
    return metrics_response()


# ---------------------------------------------------------------------------
# Dashboard stats
# ---------------------------------------------------------------------------


@app.get("/api/dashboard", response_model=DashboardStats, tags=["dashboard"])
async def get_dashboard_stats(
    request: Request,
    _: int = None,
) -> DashboardStats:
    from sqlalchemy import func, select

    from app.database import AsyncSessionLocal
    from app.models import (
        ActionItem,
        ActionItemStatus,
        Incident,
        Runbook,
        RunbookStatus,
        Service,
    )
    from app.routers.auth import require_auth

    # Manually check auth for this route
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        from fastapi import HTTPException

        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")

    from app.auth import get_current_user_id

    token = auth_header[7:]
    user_id = await get_current_user_id(token)
    if user_id is None:
        from fastapi import HTTPException

        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")

    async with AsyncSessionLocal() as db:
        rb_result = await db.execute(select(Runbook))
        all_runbooks = rb_result.scalars().all()

        fresh = sum(1 for r in all_runbooks if r.status == RunbookStatus.fresh)
        warning = sum(1 for r in all_runbooks if r.status == RunbookStatus.warning)
        stale = sum(1 for r in all_runbooks if r.status == RunbookStatus.stale)
        needs_review = sum(1 for r in all_runbooks if r.needs_review)

        inc_result = await db.execute(select(Incident).where(Incident.resolved_at.is_(None)))
        open_incidents = len(inc_result.scalars().all())

        ai_result = await db.execute(
            select(ActionItem).where(ActionItem.status != ActionItemStatus.done)
        )
        open_action_items = len(ai_result.scalars().all())

        svc_result = await db.execute(select(Service))
        services_total = len(svc_result.scalars().all())

    return DashboardStats(
        runbook_total=len(all_runbooks),
        fresh_count=fresh,
        warning_count=warning,
        stale_count=stale,
        needs_review_count=needs_review,
        open_incidents=open_incidents,
        open_action_items=open_action_items,
        services_total=services_total,
    )


# ---------------------------------------------------------------------------
# Graceful shutdown signal handling
# ---------------------------------------------------------------------------


def _handle_sigterm(signum: int, frame: Any) -> None:
    logger.info("SIGTERM received — initiating graceful shutdown")
    sys.exit(0)


signal.signal(signal.SIGTERM, _handle_sigterm)
# test
# test
# test
