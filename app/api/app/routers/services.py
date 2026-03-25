import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.database import get_db
from app.models import Runbook, RunbookStatus, Service
from app.routers.auth import require_auth
from app.schemas import ServiceCreate, ServiceDetailResponse, ServiceResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/services", tags=["services"])


@router.get("", response_model=list[ServiceDetailResponse])
async def list_services(
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> list[ServiceDetailResponse]:
    result = await db.execute(
        select(Service).options(selectinload(Service.runbooks)).order_by(Service.name)
    )
    services = result.scalars().all()

    out = []
    for svc in services:
        stale_count = sum(1 for r in svc.runbooks if r.status == RunbookStatus.stale)
        out.append(
            ServiceDetailResponse(
                **ServiceResponse.model_validate(svc).model_dump(),
                runbook_count=len(svc.runbooks),
                stale_count=stale_count,
            )
        )
    return out


@router.post("", response_model=ServiceResponse, status_code=status.HTTP_201_CREATED)
async def create_service(
    payload: ServiceCreate,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> ServiceResponse:
    existing = await db.execute(select(Service).where(Service.name == payload.name))
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Service '{payload.name}' already exists",
        )

    service = Service(
        name=payload.name,
        description=payload.description,
        owner_team=payload.owner_team,
    )
    db.add(service)
    await db.commit()
    await db.refresh(service)

    logger.info("Service created", extra={"service_id": service.id, "name": service.name})
    return ServiceResponse.model_validate(service)


@router.get("/{service_id}", response_model=ServiceDetailResponse)
async def get_service(
    service_id: int,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> ServiceDetailResponse:
    result = await db.execute(
        select(Service)
        .options(selectinload(Service.runbooks))
        .where(Service.id == service_id)
    )
    service = result.scalar_one_or_none()

    if service is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Service not found")

    stale_count = sum(1 for r in service.runbooks if r.status == RunbookStatus.stale)
    return ServiceDetailResponse(
        **ServiceResponse.model_validate(service).model_dump(),
        runbook_count=len(service.runbooks),
        stale_count=stale_count,
    )
