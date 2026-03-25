import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.metrics import RUNBOOK_COUNT
from app.models import Runbook, RunbookStatus, RunbookStep, Service
from app.routers.auth import require_auth
from app.schemas import (
    RunbookCreate,
    RunbookDetailResponse,
    RunbookResponse,
    RunbookStepResponse,
    RunbookUpdate,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/runbooks", tags=["runbooks"])


def _runbook_to_response(rb: Runbook) -> RunbookResponse:
    return RunbookResponse(
        id=rb.id,
        title=rb.title,
        content_md=rb.content_md,
        service_id=rb.service_id,
        service_name=rb.service.name if rb.service else None,
        last_verified_at=rb.last_verified_at,
        staleness_days=rb.staleness_days,
        status=rb.status,
        needs_review=rb.needs_review,
        created_at=rb.created_at,
        updated_at=rb.updated_at,
    )


async def _update_runbook_gauge(db: AsyncSession) -> None:
    for s in RunbookStatus:
        result = await db.execute(
            select(Runbook).where(Runbook.status == s)
        )
        count = len(result.scalars().all())
        RUNBOOK_COUNT.labels(status=s.value).set(count)


@router.get("", response_model=list[RunbookResponse])
async def list_runbooks(
    service_id: int | None = Query(default=None),
    status_filter: RunbookStatus | None = Query(default=None, alias="status"),
    needs_review: bool | None = Query(default=None),
    search: str | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> list[RunbookResponse]:
    query = (
        select(Runbook)
        .options(selectinload(Runbook.service))
        .order_by(Runbook.staleness_days.desc(), Runbook.title)
    )

    if service_id is not None:
        query = query.where(Runbook.service_id == service_id)
    if status_filter is not None:
        query = query.where(Runbook.status == status_filter)
    if needs_review is not None:
        query = query.where(Runbook.needs_review == needs_review)
    if search:
        query = query.where(Runbook.title.ilike(f"%{search}%"))

    result = await db.execute(query)
    runbooks = result.scalars().all()
    return [_runbook_to_response(rb) for rb in runbooks]


@router.post("", response_model=RunbookDetailResponse, status_code=status.HTTP_201_CREATED)
async def create_runbook(
    payload: RunbookCreate,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> RunbookDetailResponse:
    service = await db.get(Service, payload.service_id)
    if service is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    runbook = Runbook(
        title=payload.title,
        content_md=payload.content_md,
        service_id=payload.service_id,
        last_verified_at=now,
        staleness_days=0,
        status=RunbookStatus.fresh,
    )
    db.add(runbook)
    await db.flush()

    for step_data in payload.steps:
        step = RunbookStep(
            runbook_id=runbook.id,
            order=step_data.order,
            description=step_data.description,
        )
        db.add(step)

    await db.commit()
    await db.refresh(runbook)

    result = await db.execute(
        select(Runbook)
        .options(selectinload(Runbook.service), selectinload(Runbook.steps))
        .where(Runbook.id == runbook.id)
    )
    runbook = result.scalar_one()

    logger.info("Runbook created", extra={"runbook_id": runbook.id, "title": runbook.title})
    return RunbookDetailResponse(
        **_runbook_to_response(runbook).model_dump(),
        steps=[RunbookStepResponse.model_validate(s) for s in runbook.steps],
    )


@router.get("/{runbook_id}", response_model=RunbookDetailResponse)
async def get_runbook(
    runbook_id: int,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> RunbookDetailResponse:
    result = await db.execute(
        select(Runbook)
        .options(selectinload(Runbook.service), selectinload(Runbook.steps))
        .where(Runbook.id == runbook_id)
    )
    runbook = result.scalar_one_or_none()

    if runbook is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Runbook not found")

    return RunbookDetailResponse(
        **_runbook_to_response(runbook).model_dump(),
        steps=[RunbookStepResponse.model_validate(s) for s in runbook.steps],
    )


@router.put("/{runbook_id}", response_model=RunbookDetailResponse)
async def update_runbook(
    runbook_id: int,
    payload: RunbookUpdate,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> RunbookDetailResponse:
    result = await db.execute(
        select(Runbook)
        .options(selectinload(Runbook.service), selectinload(Runbook.steps))
        .where(Runbook.id == runbook_id)
    )
    runbook = result.scalar_one_or_none()

    if runbook is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Runbook not found")

    if payload.title is not None:
        runbook.title = payload.title
    if payload.content_md is not None:
        runbook.content_md = payload.content_md

    await db.commit()
    await db.refresh(runbook)

    logger.info("Runbook updated", extra={"runbook_id": runbook.id})
    return RunbookDetailResponse(
        **_runbook_to_response(runbook).model_dump(),
        steps=[RunbookStepResponse.model_validate(s) for s in runbook.steps],
    )


@router.post("/{runbook_id}/verify", response_model=RunbookResponse)
async def verify_runbook(
    runbook_id: int,
    db: AsyncSession = Depends(get_db),
    user_id: int = Depends(require_auth),
) -> RunbookResponse:
    result = await db.execute(
        select(Runbook)
        .options(selectinload(Runbook.service))
        .where(Runbook.id == runbook_id)
    )
    runbook = result.scalar_one_or_none()

    if runbook is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Runbook not found")

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    runbook.last_verified_at = now
    runbook.staleness_days = 0
    runbook.status = RunbookStatus.fresh
    runbook.needs_review = False

    await db.commit()
    await db.refresh(runbook)
    await _update_runbook_gauge(db)

    logger.info(
        "Runbook verified",
        extra={"runbook_id": runbook.id, "verified_by": user_id},
    )
    return _runbook_to_response(runbook)


@router.get("/{runbook_id}/history", response_model=list[dict])
async def get_runbook_history(
    runbook_id: int,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> list[dict]:
    runbook = await db.get(Runbook, runbook_id)
    if runbook is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Runbook not found")

    # History via incident links
    result = await db.execute(
        select(Runbook)
        .options(selectinload(Runbook.incident_links))
        .where(Runbook.id == runbook_id)
    )
    rb = result.scalar_one()

    history = [
        {
            "incident_id": link.incident_id,
            "was_accurate": link.was_accurate,
        }
        for link in rb.incident_links
    ]
    return history
