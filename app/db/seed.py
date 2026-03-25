#!/usr/bin/env python3
"""
Seed script — creates realistic demo data for Runmatic.

Run from within the API container (all dependencies available):
    python /app/db/seed.py

Or standalone with the API virtualenv activated:
    DATABASE_URL=postgresql+asyncpg://... python seed.py
"""
import os
import sys
from datetime import datetime, timedelta, timezone

# Import models from the API package
api_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../api")
sys.path.insert(0, api_dir)

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Convert asyncpg URL to sync for seed script
database_url = os.environ.get(
    "DATABASE_URL",
    "postgresql+asyncpg://runmatic:password@postgres:5432/runmatic",
).replace("postgresql+asyncpg://", "postgresql+psycopg2://")

engine = create_engine(database_url, echo=False)
Session = sessionmaker(bind=engine)

from app.auth import get_password_hash  # noqa: E402
from app.models import (  # noqa: E402
    ActionItem,
    ActionItemStatus,
    Deployment,
    Incident,
    IncidentRunbook,
    IncidentSeverity,
    Runbook,
    RunbookStatus,
    RunbookStep,
    Service,
    User,
)


def seed() -> None:
    now = datetime.now(timezone.utc).replace(tzinfo=None)

    with Session() as session:
        # ------------------------------------------------------------------
        # Guard: skip if data already exists
        # ------------------------------------------------------------------
        if session.query(User).first():
            print("Seed data already present — skipping")
            return

        # ------------------------------------------------------------------
        # Demo user
        # ------------------------------------------------------------------
        user = User(
            email="demo@runmatic.dev",
            hashed_password=get_password_hash("demo1234"),
            created_at=now,
        )
        session.add(user)
        session.flush()

        # ------------------------------------------------------------------
        # Services
        # ------------------------------------------------------------------
        payments = Service(
            name="payments-api",
            description="Core payment processing and transaction management",
            owner_team="Payments Team",
            created_at=now - timedelta(days=180),
        )
        users_svc = Service(
            name="user-service",
            description="User authentication, profiles, and permissions",
            owner_team="Platform Team",
            created_at=now - timedelta(days=150),
        )
        notifications = Service(
            name="notification-service",
            description="Email, SMS, and push notification delivery",
            owner_team="Communications Team",
            created_at=now - timedelta(days=120),
        )
        session.add_all([payments, users_svc, notifications])
        session.flush()

        # ------------------------------------------------------------------
        # Runbooks (8 total, varying staleness)
        # ------------------------------------------------------------------
        def make_runbook(
            title: str,
            service: Service,
            verified_days_ago: int,
            content: str,
            needs_review: bool = False,
        ) -> Runbook:
            last_verified = now - timedelta(days=verified_days_ago)
            if verified_days_ago < 7:
                status = RunbookStatus.fresh
            elif verified_days_ago <= 30:
                status = RunbookStatus.warning
            else:
                status = RunbookStatus.stale

            return Runbook(
                title=title,
                content_md=content,
                service_id=service.id,
                last_verified_at=last_verified,
                staleness_days=verified_days_ago,
                status=status,
                needs_review=needs_review,
                created_at=now - timedelta(days=verified_days_ago + 30),
                updated_at=last_verified,
            )

        # Fresh runbooks (< 7 days)
        rb1 = make_runbook(
            "Payment Gateway Failover",
            payments,
            2,
            "# Payment Gateway Failover\n\n"
            "## When to use this runbook\nUse this when the primary payment gateway "
            "(Stripe) is returning 5xx errors or timing out.\n\n"
            "## Prerequisites\n- Access to payment-admin dashboard\n"
            "- Backup gateway credentials in 1Password vault: `payments/backup-gateway`\n\n"
            "## Steps\n1. Confirm Stripe status at https://status.stripe.com\n"
            "2. Check error rate in Grafana: `payments-api → Error Rate` dashboard\n"
            "3. If error rate > 10% for 5+ minutes, proceed with failover\n"
            "4. Update `PAYMENT_GATEWAY=backup` in K8s ConfigMap\n"
            "5. Rolling restart: `kubectl rollout restart deployment/payments-api`\n"
            "6. Verify transaction success rate recovers\n"
            "7. Page #payments-oncall with status update\n\n"
            "## Rollback\nRevert ConfigMap to `PAYMENT_GATEWAY=stripe` and restart.",
        )
        rb2 = make_runbook(
            "Database Connection Pool Exhaustion",
            payments,
            5,
            "# Database Connection Pool Exhaustion\n\n"
            "## Symptoms\n- `FATAL: remaining connection slots are reserved` in logs\n"
            "- API latency > 5s on all endpoints\n"
            "- Health check returning degraded\n\n"
            "## Diagnosis\n```sql\nSELECT count(*), state FROM pg_stat_activity "
            "GROUP BY state;\n```\n\n"
            "## Immediate fix\n1. Kill idle connections older than 5 minutes\n"
            "2. Scale payments-api to 0 replicas, wait 30s, scale back\n"
            "3. Check for long-running transactions and kill if safe",
        )

        # Warning runbooks (7-30 days)
        rb3 = make_runbook(
            "User Account Lockout Recovery",
            users_svc,
            15,
            "# User Account Lockout Recovery\n\n"
            "## When to use\nA user is locked out and cannot reset their password "
            "via self-service.\n\n"
            "## Steps\n1. Verify user identity via support ticket\n"
            "2. Connect to user-service database\n"
            "3. `UPDATE users SET failed_attempts=0, locked_until=NULL WHERE email=?`\n"
            "4. Notify user via support ticket\n"
            "5. Log action in audit trail",
        )
        rb4 = make_runbook(
            "OAuth Token Revocation",
            users_svc,
            22,
            "# OAuth Token Revocation\n\n"
            "## Purpose\nRevoke all active tokens for a compromised user account.\n\n"
            "## Steps\n1. Identify compromised account\n"
            "2. `redis-cli DEL session:{user_id}`\n"
            "3. Rotate the user's API keys in admin dashboard\n"
            "4. Force password reset\n"
            "5. Review recent activity for suspicious actions",
        )
        rb5 = make_runbook(
            "Email Delivery Failure Investigation",
            notifications,
            28,
            "# Email Delivery Failure Investigation\n\n"
            "## Symptoms\n- Users not receiving verification emails\n"
            "- Email bounce rate > 5% in SendGrid dashboard\n\n"
            "## Investigation steps\n1. Check SendGrid status page\n"
            "2. Verify API key rotation schedule (rotated quarterly)\n"
            "3. Check notification-service logs for SMTP errors\n"
            "4. Review suppression list for affected domains",
        )

        # Stale runbooks (> 30 days)
        rb6 = make_runbook(
            "On-Call Escalation Procedure",
            payments,
            45,
            "# On-Call Escalation Procedure\n\n"
            "## Escalation path\n1. Primary on-call (PagerDuty)\n"
            "2. Secondary on-call (15 min no response)\n"
            "3. Engineering Manager (30 min no response)\n\n"
            "## ⚠️ This runbook may be stale\n"
            "Verify escalation contacts in PagerDuty before using in a live incident.",
            needs_review=True,
        )
        rb7 = make_runbook(
            "SMS Gateway Fallback",
            notifications,
            67,
            "# SMS Gateway Fallback\n\n"
            "## Warning\nThis runbook references Twilio v2 API which was deprecated. "
            "Verify current configuration before executing.\n\n"
            "## Steps (verify before use)\n1. Check current SMS provider in config\n"
            "2. Follow provider-specific failover procedure",
            needs_review=True,
        )
        rb8 = make_runbook(
            "Kubernetes Node Eviction Recovery",
            users_svc,
            90,
            "# Kubernetes Node Eviction Recovery\n\n"
            "## ⚠️ STALE — References EKS 1.24 which is no longer in use\n\n"
            "## Steps\n1. Identify evicted node: `kubectl get nodes`\n"
            "2. Cordon node: `kubectl cordon <node>`\n"
            "3. Drain: `kubectl drain <node> --ignore-daemonsets`\n"
            "4. Investigate root cause in CloudWatch\n"
            "5. Terminate and replace node via ASG",
            needs_review=True,
        )

        session.add_all([rb1, rb2, rb3, rb4, rb5, rb6, rb7, rb8])
        session.flush()

        # ------------------------------------------------------------------
        # Steps for rb1 (Payment Gateway Failover)
        # ------------------------------------------------------------------
        steps = [
            RunbookStep(runbook_id=rb1.id, order=1, description="Confirm Stripe status at status.stripe.com"),
            RunbookStep(runbook_id=rb1.id, order=2, description="Check error rate in Grafana payments-api dashboard"),
            RunbookStep(runbook_id=rb1.id, order=3, description="If error rate > 10% for 5+ minutes, initiate failover"),
            RunbookStep(runbook_id=rb1.id, order=4, description="Update PAYMENT_GATEWAY=backup in K8s ConfigMap"),
            RunbookStep(runbook_id=rb1.id, order=5, description="Rolling restart: kubectl rollout restart deployment/payments-api"),
            RunbookStep(runbook_id=rb1.id, order=6, description="Verify transaction success rate recovers to baseline"),
            RunbookStep(runbook_id=rb1.id, order=7, description="Post status update in #payments-oncall"),
        ]
        session.add_all(steps)

        # ------------------------------------------------------------------
        # Incidents
        # ------------------------------------------------------------------
        inc1 = Incident(
            title="Payment Gateway Timeout — Stripe degraded",
            severity=IncidentSeverity.p2,
            started_at=now - timedelta(days=12, hours=3),
            resolved_at=now - timedelta(days=12, hours=1),
            service_id=payments.id,
        )
        inc2 = Incident(
            title="User authentication latency spike",
            severity=IncidentSeverity.p3,
            started_at=now - timedelta(hours=2),
            resolved_at=None,  # Still open
            service_id=users_svc.id,
        )
        session.add_all([inc1, inc2])
        session.flush()

        # Link runbooks to incidents
        link1 = IncidentRunbook(
            incident_id=inc1.id,
            runbook_id=rb1.id,
            was_accurate=True,
        )
        link2 = IncidentRunbook(
            incident_id=inc1.id,
            runbook_id=rb2.id,
            was_accurate=True,
        )
        link3 = IncidentRunbook(
            incident_id=inc2.id,
            runbook_id=rb3.id,
            was_accurate=None,  # Still being evaluated
        )
        session.add_all([link1, link2, link3])

        # ------------------------------------------------------------------
        # Action items
        # ------------------------------------------------------------------
        ai1 = ActionItem(
            description="Update escalation contacts in On-Call Escalation Procedure runbook — several contacts have left",
            incident_id=inc1.id,
            runbook_id=rb6.id,
            status=ActionItemStatus.open,
            due_date=now + timedelta(days=7),
            created_at=now - timedelta(days=11),
        )
        ai2 = ActionItem(
            description="Replace Twilio v2 references in SMS Gateway Fallback runbook with v3 API",
            incident_id=None,
            runbook_id=rb7.id,
            status=ActionItemStatus.in_progress,
            due_date=now + timedelta(days=3),
            created_at=now - timedelta(days=30),
        )
        ai3 = ActionItem(
            description="Add Stripe backup gateway credentials to 1Password vault",
            incident_id=inc1.id,
            runbook_id=rb1.id,
            status=ActionItemStatus.open,
            due_date=now + timedelta(days=14),
            created_at=now - timedelta(days=11),
        )
        ai4 = ActionItem(
            description="Update Kubernetes runbook to reflect EKS 1.30 upgrade",
            incident_id=None,
            runbook_id=rb8.id,
            status=ActionItemStatus.done,
            due_date=now - timedelta(days=5),
            created_at=now - timedelta(days=60),
        )
        session.add_all([ai1, ai2, ai3, ai4])

        # ------------------------------------------------------------------
        # Deployments (to show webhook flow)
        # ------------------------------------------------------------------
        dep1 = Deployment(
            service_id=payments.id,
            version="v2.14.1",
            deployed_at=now - timedelta(days=2, hours=6),
            triggered_by="github-actions",
        )
        dep2 = Deployment(
            service_id=users_svc.id,
            version="v1.9.3",
            deployed_at=now - timedelta(hours=4),
            triggered_by="github-actions",
        )
        session.add_all([dep1, dep2])
        session.commit()

    print(
        "Seed complete:\n"
        "  3 services\n"
        "  8 runbooks (2 fresh, 3 warning, 3 stale)\n"
        "  2 incidents (1 resolved, 1 open)\n"
        "  4 action items (2 open, 1 in-progress, 1 done)\n"
        "  2 deployments\n"
        "  1 user: demo@runmatic.dev / demo1234"
    )


if __name__ == "__main__":
    seed()
