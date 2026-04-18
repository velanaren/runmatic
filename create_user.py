#!/usr/bin/env python3
import asyncio
import sys
sys.path.insert(0, '/app')

from app.auth import get_password_hash
from app.models import User, Service, Runbook, RunbookStatus, RunbookStep
from app.database import AsyncSessionLocal
from datetime import datetime, timezone, timedelta

async def create_user_and_data():
    async with AsyncSessionLocal() as session:
        now = datetime.now(timezone.utc).replace(tzinfo=None)

        # Create user
        user = User(
            email='demo@runmatic.dev',
            hashed_password=get_password_hash('demo1234'),
            created_at=now
        )
        session.add(user)
        await session.flush()

        # Create services
        api_svc = Service(
            name='runmatic-api',
            description='Core API service for Runmatic platform',
            owner_team='Platform Team',
            created_at=now - timedelta(days=90)
        )
        worker_svc = Service(
            name='runmatic-worker',
            description='Background job processor',
            owner_team='Platform Team',
            created_at=now - timedelta(days=90)
        )
        session.add_all([api_svc, worker_svc])
        await session.flush()

        # Create runbooks
        rb1 = Runbook(
            title='API Health Check Failure',
            content_md='# API Health Check Failure\n\n## Symptoms\n- Health endpoint returns 503\n- Database connection errors in logs\n\n## Steps\n1. Check database connectivity\n2. Verify Redis connection\n3. Check API logs for errors\n4. Restart API container if needed',
            service_id=api_svc.id,
            last_verified_at=now - timedelta(days=2),
            staleness_days=2,
            status=RunbookStatus.fresh,
            created_at=now - timedelta(days=30)
        )

        rb2 = Runbook(
            title='Worker Job Queue Backup',
            content_md='# Worker Job Queue Backup\n\n## Symptoms\n- Redis queue depth increasing\n- Jobs not processing\n\n## Investigation\n1. Check worker container status\n2. Review worker logs\n3. Check Redis memory usage\n4. Verify job consumer is running',
            service_id=worker_svc.id,
            last_verified_at=now - timedelta(days=8),
            staleness_days=8,
            status=RunbookStatus.fresh,
            created_at=now - timedelta(days=45)
        )

        rb3 = Runbook(
            title='Database Connection Pool Exhaustion',
            content_md='# Database Connection Pool Exhaustion\n\n## When to use\nAPI showing connection timeout errors.\n\n## Steps\n1. Check active connections: `SELECT count(*) FROM pg_stat_activity`\n2. Identify long-running queries\n3. Scale API replicas if needed\n4. Increase pool size if consistently hitting limit',
            service_id=api_svc.id,
            last_verified_at=now - timedelta(days=20),
            staleness_days=20,
            status=RunbookStatus.warning,
            created_at=now - timedelta(days=60)
        )

        rb4 = Runbook(
            title='Container Restart Loop',
            content_md='# Container Restart Loop\n\n## ⚠️ May need review\n\n## Diagnosis\n1. Check restart count: `docker ps`\n2. Review container logs\n3. Check resource limits\n4. Verify dependencies are healthy',
            service_id=api_svc.id,
            last_verified_at=now - timedelta(days=50),
            staleness_days=50,
            status=RunbookStatus.stale,
            needs_review=True,
            created_at=now - timedelta(days=80)
        )

        session.add_all([rb1, rb2, rb3, rb4])
        await session.flush()

        # Add steps to rb1
        steps = [
            RunbookStep(runbook_id=rb1.id, order=1, description='Check database connectivity from API container'),
            RunbookStep(runbook_id=rb1.id, order=2, description='Verify Redis connection with redis-cli PING'),
            RunbookStep(runbook_id=rb1.id, order=3, description='Review API logs for stack traces'),
            RunbookStep(runbook_id=rb1.id, order=4, description='Restart API container: docker compose restart api'),
        ]
        session.add_all(steps)

        await session.commit()
        print('''
✓ Demo data created:
  User: demo@runmatic.dev / demo1234
  2 services (runmatic-api, runmatic-worker)
  4 runbooks (2 fresh, 1 warning, 1 stale)
''')

asyncio.run(create_user_and_data())
