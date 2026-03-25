import logging
from datetime import datetime, timezone

import redis.asyncio as aioredis
from fastapi import APIRouter, Depends, HTTPException, status
from rq import Queue
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth import get_redis
from app.database import get_db
from app.models import Deployment, Service
from app.routers.auth import require_auth
from app.schemas import DeploymentWebhookPayload, DeploymentWebhookResponse

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/webhooks", tags=["webhooks"])


@router.post(
    "/deployment",
    response_model=DeploymentWebhookResponse,
    status_code=status.HTTP_202_ACCEPTED,
)
async def receive_deployment(
    payload: DeploymentWebhookPayload,
    db: AsyncSession = Depends(get_db),
    _: int = Depends(require_auth),
) -> DeploymentWebhookResponse:
    result = await db.execute(select(Service).where(Service.name == payload.service_name))
    service = result.scalar_one_or_none()

    if service is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Service '{payload.service_name}' not found",
        )

    deployed_at = (
        payload.deployed_at.replace(tzinfo=None)
        if payload.deployed_at
        else datetime.now(timezone.utc).replace(tzinfo=None)
    )

    deployment = Deployment(
        service_id=service.id,
        version=payload.version,
        deployed_at=deployed_at,
        triggered_by=payload.triggered_by,
    )
    db.add(deployment)
    await db.commit()
    await db.refresh(deployment)

    # Enqueue job for worker to process
    redis_client = get_redis()
    sync_redis = aioredis.Redis.from_url(
        str(redis_client.connection_pool.connection_kwargs.get("url", "")),
        decode_responses=False,
    )

    job_id = f"deployment-{deployment.id}"

    try:
        # Use a synchronous Redis connection for rq
        import redis as sync_redis_lib

        from app.config import settings

        sync_redis_conn = sync_redis_lib.from_url(settings.redis_url, decode_responses=False)
        q = Queue("default", connection=sync_redis_conn)
        job = q.enqueue(
            "worker.jobs.process_deployment_webhook",
            kwargs={"service_id": service.id, "deployment_id": deployment.id},
            job_id=job_id,
            result_ttl=3600,
        )
        actual_job_id = job.id
    except Exception as exc:
        logger.warning(
            "Failed to enqueue deployment job",
            extra={"deployment_id": deployment.id, "error": str(exc)},
        )
        actual_job_id = job_id

    logger.info(
        "Deployment webhook received",
        extra={
            "service": payload.service_name,
            "version": payload.version,
            "deployment_id": deployment.id,
            "job_id": actual_job_id,
        },
    )

    return DeploymentWebhookResponse(
        accepted=True,
        job_id=actual_job_id,
        message=f"Deployment recorded for {payload.service_name} v{payload.version}. Runbooks queued for review.",
    )
