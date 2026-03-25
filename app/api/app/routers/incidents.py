import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import Incident, IncidentRunbook, Runbook, Service
from app.routers.auth import require_auth
from app.schemas import (
    IncidentCreate,
    IncidentDetailResponse,
    IncidentLinkRunbook,
    IncidentResolve,
    IncidentResponse,
    IncidentRunbookResponse,
)

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/incidents", tags=["incidents"])


def _incident_to_response(incident: Incident) -> IncidentResponse:
    return IncidentResponse(
        id=incident.id,
        title=incident.title,
        severity=incident.severity,
        started_at=incident.started_at,
        resolved_at=incident.resolved_at,
        service_id=incident.service_id,
        service_name=incident.service.name if incident.service else None,
    )


@router.get("", response_model=list[IncidentResponse])
async def list_incidents(
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> list[IncidentResponse]:
    result = await db.execute(
        select(Incident)
        .options(selectinload(Incident.service))
        .order_by(Incident.started_at.desc())
    )
    incidents = result.scalars().all()
    return [_incident_to_response(inc) for inc in incidents]


@router.post("", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED)
async def create_incident(
    payload: IncidentCreate,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> IncidentResponse:
    service = await db.get(Service, payload.service_id)
    if service is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")

    incident = Incident(
        title=payload.title,
        severity=payload.severity,
        started_at=payload.started_at.replace(tzinfo=None),
        service_id=payload.service_id,
    )
    db.add(incident)
    await db.commit()
    await db.refresh(incident)

    result = await db.execute(
        select(Incident)
        .options(selectinload(Incident.service))
        .where(Incident.id == incident.id)
    )
    incident = result.scalar_one()

    logger.info("Incident created", extra={"incident_id": incident.id, "title": incident.title})
    return _incident_to_response(incident)


@router.put("/{incident_id}/resolve", response_model=IncidentResponse)
async def resolve_incident(
    incident_id: int,
    payload: IncidentResolve,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> IncidentResponse:
    result = await db.execute(
        select(Incident)
        .options(selectinload(Incident.service))
        .where(Incident.id == incident_id)
    )
    incident = result.scalar_one_or_none()

    if incident is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Incident not found")

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    incident.resolved_at = (
        payload.resolved_at.replace(tzinfo=None) if payload.resolved_at else now
    )

    await db.commit()
    await db.refresh(incident)

    logger.info("Incident resolved", extra={"incident_id": incident.id})
    return _incident_to_response(incident)


@router.post("/{incident_id}/runbooks", response_model=IncidentDetailResponse)
async def link_runbook_to_incident(
    incident_id: int,
    payload: IncidentLinkRunbook,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> IncidentDetailResponse:
    result = await db.execute(
        select(Incident)
        .options(selectinload(Incident.service), selectinload(Incident.runbook_links))
        .where(Incident.id == incident_id)
    )
    incident = result.scalar_one_or_none()

    if incident is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Incident not found")

    runbook = await db.get(Runbook, payload.runbook_id)
    if runbook is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Runbook not found")

    # Check for existing link
    existing_link = next(
        (lnk for lnk in incident.runbook_links if lnk.runbook_id == payload.runbook_id), None
    )
    if existing_link is not None:
        existing_link.was_accurate = payload.was_accurate
    else:
        link = IncidentRunbook(
            incident_id=incident_id,
            runbook_id=payload.runbook_id,
            was_accurate=payload.was_accurate,
        )
        db.add(link)

    await db.commit()

    result = await db.execute(
        select(Incident)
        .options(
            selectinload(Incident.service),
            selectinload(Incident.runbook_links).selectinload(IncidentRunbook.runbook),
        )
        .where(Incident.id == incident_id)
    )
    incident = result.scalar_one()

    logger.info(
        "Runbook linked to incident",
        extra={"incident_id": incident_id, "runbook_id": payload.runbook_id},
    )

    linked = [
        IncidentRunbookResponse(
            runbook_id=lnk.runbook_id,
            runbook_title=lnk.runbook.title if lnk.runbook else None,
            was_accurate=lnk.was_accurate,
        )
        for lnk in incident.runbook_links
    ]

    return IncidentDetailResponse(
        **_incident_to_response(incident).model_dump(),
        linked_runbooks=linked,
    )
