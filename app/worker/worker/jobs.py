"""
Runmatic Worker Jobs
--------------------
Jobs executed by APScheduler (scheduled) and rq (queue-based).
All database access uses synchronous SQLAlchemy with psycopg2.
"""
import enum
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session, sessionmaker

from worker.config import settings

logger = logging.getLogger(__name__)

_engine = None
_SessionLocal = None


def _get_session() -> Session:
    global _engine, _SessionLocal
    if _engine is None:
        _engine = create_engine(
            settings.sync_database_url,
            pool_size=5,
            max_overflow=10,
            pool_pre_ping=True,
            pool_recycle=300,
        )
        _SessionLocal = sessionmaker(bind=_engine, expire_on_commit=False)
    return _SessionLocal()


# ---------------------------------------------------------------------------
# Scheduled job: hourly staleness recalculation
# ---------------------------------------------------------------------------


def recalculate_staleness() -> None:
    """
    Scan all runbooks, compute staleness_days from last_verified_at,
    update status (fresh / warning / stale), and persist to database.
    Runs every hour via APScheduler.
    """
    logger.info("Starting staleness recalculation")
    now = datetime.now(timezone.utc).replace(tzinfo=None)

    try:
        with _get_session() as session:
            rows = session.execute(
                text("SELECT id, last_verified_at FROM runbooks")
            ).fetchall()

            updated = 0
            for row in rows:
                runbook_id, last_verified_at = row[0], row[1]

                if last_verified_at is None:
                    staleness_days = 999
                else:
                    staleness_days = (now - last_verified_at).days

                if staleness_days < settings.staleness_threshold_days:
                    new_status = "fresh"
                elif staleness_days <= 30:
                    new_status = "warning"
                else:
                    new_status = "stale"

                session.execute(
                    text(
                        "UPDATE runbooks SET staleness_days = :days, status = :status, "
                        "updated_at = :now WHERE id = :id"
                    ),
                    {"days": staleness_days, "status": new_status, "now": now, "id": runbook_id},
                )
                updated += 1

            session.commit()

        logger.info("Staleness recalculation complete", extra={"runbooks_updated": updated})

    except Exception as exc:
        logger.error("Staleness recalculation failed", extra={"error": str(exc)}, exc_info=True)


# ---------------------------------------------------------------------------
# Queue job: process deployment webhook
# ---------------------------------------------------------------------------


def process_deployment_webhook(service_id: int, deployment_id: int) -> None:
    """
    For a given deployment, find all runbooks linked to the service
    and mark them needs_review=true. Called by rq worker.
    """
    logger.info(
        "Processing deployment webhook",
        extra={"service_id": service_id, "deployment_id": deployment_id},
    )

    try:
        with _get_session() as session:
            result = session.execute(
                text("SELECT id FROM runbooks WHERE service_id = :sid"),
                {"sid": service_id},
            ).fetchall()

            runbook_ids = [row[0] for row in result]

            if runbook_ids:
                session.execute(
                    text(
                        "UPDATE runbooks SET needs_review = true WHERE service_id = :sid"
                    ),
                    {"sid": service_id},
                )
                session.commit()

        logger.info(
            "Deployment webhook processed",
            extra={
                "deployment_id": deployment_id,
                "runbooks_flagged": len(runbook_ids),
            },
        )

    except Exception as exc:
        logger.error(
            "Deployment webhook processing failed",
            extra={"deployment_id": deployment_id, "error": str(exc)},
            exc_info=True,
        )
        raise


# ---------------------------------------------------------------------------
# Queue job: send notification (stub)
# ---------------------------------------------------------------------------


def send_notification(notification_type: str, payload: dict) -> None:
    """
    Notification sender stub. Logs intent; real Slack/email integration
    is implemented in Sprint 26.
    """
    logger.info(
        "Notification intent logged (stub — Sprint 26 implements delivery)",
        extra={"notification_type": notification_type, "payload": payload},
    )


# ---------------------------------------------------------------------------
# Scheduled job: daily session/token cleanup
# ---------------------------------------------------------------------------


def cleanup_expired_sessions() -> None:
    """
    Delete expired data. Redis TTLs handle most session cleanup automatically;
    this job handles any database-side token/session records if added later.
    Runs daily at 02:00 UTC.
    """
    logger.info("Starting daily session/token cleanup")

    try:
        with _get_session() as session:
            # Placeholder: remove action items that are done and older than 90 days
            cutoff = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=90)
            result = session.execute(
                text(
                    "DELETE FROM action_items WHERE status = 'done' AND created_at < :cutoff "
                    "RETURNING id"
                ),
                {"cutoff": cutoff},
            )
            deleted = result.rowcount
            session.commit()

        logger.info("Cleanup complete", extra={"action_items_archived": deleted})

    except Exception as exc:
        logger.error("Session cleanup failed", extra={"error": str(exc)}, exc_info=True)
