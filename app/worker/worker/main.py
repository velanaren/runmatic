"""
Runmatic Worker — Main Entry Point
------------------------------------
Runs two concurrent components:
  1. APScheduler: scheduled jobs (staleness recalc, daily cleanup)
  2. rq Worker: queue-based jobs (deployment webhooks, notifications)

Handles SIGTERM gracefully: finishes the current job before exiting.
"""
import logging
import signal
import sys
import threading
import time

import redis
from apscheduler.schedulers.background import BackgroundScheduler
from rq import Queue, Worker

from worker.config import settings
from worker.jobs import cleanup_expired_sessions, recalculate_staleness
from worker.logging_config import configure_logging

configure_logging(settings.log_level)
logger = logging.getLogger(__name__)

_shutdown_requested = False


def start_scheduler() -> BackgroundScheduler:
    scheduler = BackgroundScheduler(timezone="UTC")

    scheduler.add_job(
        recalculate_staleness,
        trigger="interval",
        seconds=settings.staleness_check_interval,
        id="staleness_recalc",
        replace_existing=True,
        max_instances=1,
    )

    scheduler.add_job(
        cleanup_expired_sessions,
        trigger="cron",
        hour=2,
        minute=0,
        id="daily_cleanup",
        replace_existing=True,
        max_instances=1,
    )

    scheduler.start()
    logger.info(
        "APScheduler started",
        extra={
            "staleness_interval_seconds": settings.staleness_check_interval,
            "cleanup_cron": "02:00 UTC daily",
        },
    )
    return scheduler


def set_heartbeat(redis_conn: redis.Redis) -> None:
    """Set a Redis heartbeat key so healthcheck.py can verify the worker is alive."""
    redis_conn.setex("worker:heartbeat", 120, "alive")


def start_heartbeat(redis_conn: redis.Redis) -> threading.Thread:
    """Run heartbeat in a background thread so rq can own the main thread."""
    def _run():
        while not _shutdown_requested:
            set_heartbeat(redis_conn)
            time.sleep(60)

    thread = threading.Thread(target=_run, daemon=True, name="heartbeat")
    thread.start()
    return thread


def main() -> None:
    logger.info(
        "Runmatic Worker starting",
        extra={"environment": settings.log_level},
    )

    redis_conn = redis.from_url(settings.redis_url, decode_responses=False)

    try:
        redis_conn.ping()
        logger.info("Redis connection established")
    except Exception as exc:
        logger.error("Cannot connect to Redis — aborting", extra={"error": str(exc)})
        sys.exit(1)

    scheduler = start_scheduler()
    start_heartbeat(redis_conn)

    # Run staleness check immediately on startup
    try:
        recalculate_staleness()
    except Exception as exc:
        logger.warning("Initial staleness check failed", extra={"error": str(exc)})

    logger.info("Worker is running — waiting for jobs")

    # rq must run in the main thread — signal handlers cannot be installed from a background thread
    queues = [
        Queue("default", connection=redis_conn),
        Queue("notifications", connection=redis_conn),
    ]
    worker = Worker(queues, connection=redis_conn)
    worker.work(with_scheduler=False, burst=False)

    logger.info("rq worker stopped — shutting down scheduler")
    scheduler.shutdown(wait=True)
    logger.info("Worker shutdown complete")


if __name__ == "__main__":
    main()
