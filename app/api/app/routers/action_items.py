import logging

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import ActionItem, ActionItemStatus
from app.routers.auth import require_auth
from app.schemas import ActionItemCreate, ActionItemResponse, ActionItemUpdate

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/action-items", tags=["action-items"])


@router.get("", response_model=list[ActionItemResponse])
async def list_action_items(
    status_filter: ActionItemStatus | None = Query(default=None, alias="status"),
    incident_id: int | None = Query(default=None),
    runbook_id: int | None = Query(default=None),
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> list[ActionItemResponse]:
    query = select(ActionItem).order_by(ActionItem.created_at.desc())

    if status_filter is not None:
        query = query.where(ActionItem.status == status_filter)
    if incident_id is not None:
        query = query.where(ActionItem.incident_id == incident_id)
    if runbook_id is not None:
        query = query.where(ActionItem.runbook_id == runbook_id)

    result = await db.execute(query)
    items = result.scalars().all()
    return [ActionItemResponse.model_validate(item) for item in items]


@router.post("", response_model=ActionItemResponse, status_code=status.HTTP_201_CREATED)
async def create_action_item(
    payload: ActionItemCreate,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> ActionItemResponse:
    item = ActionItem(
        description=payload.description,
        incident_id=payload.incident_id,
        runbook_id=payload.runbook_id,
        due_date=payload.due_date.replace(tzinfo=None) if payload.due_date else None,
        status=ActionItemStatus.open,
    )
    db.add(item)
    await db.commit()
    await db.refresh(item)

    logger.info("Action item created", extra={"action_item_id": item.id})
    return ActionItemResponse.model_validate(item)


@router.put("/{item_id}", response_model=ActionItemResponse)
async def update_action_item(
    item_id: int,
    payload: ActionItemUpdate,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> ActionItemResponse:
    item = await db.get(ActionItem, item_id)
    if item is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Action item not found")

    if payload.status is not None:
        item.status = payload.status
    if payload.description is not None:
        item.description = payload.description
    if payload.due_date is not None:
        item.due_date = payload.due_date.replace(tzinfo=None)

    await db.commit()
    await db.refresh(item)

    logger.info(
        "Action item updated",
        extra={"action_item_id": item.id, "status": item.status.value},
    )
    return ActionItemResponse.model_validate(item)
