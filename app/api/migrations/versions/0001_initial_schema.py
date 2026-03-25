"""Initial schema — all tables

Revision ID: 0001
Revises:
Create Date: 2026-03-17 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("email"),
    )
    op.create_index("ix_users_email", "users", ["email"])

    op.create_table(
        "services",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("owner_team", sa.String(255), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("name"),
    )
    op.create_index("ix_services_name", "services", ["name"])

    op.create_table(
        "runbooks",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("content_md", sa.Text(), nullable=True),
        sa.Column("service_id", sa.Integer(), nullable=False),
        sa.Column("last_verified_at", sa.DateTime(), nullable=True),
        sa.Column("staleness_days", sa.Integer(), nullable=False, server_default="0"),
        sa.Column(
            "status",
            sa.Enum("fresh", "warning", "stale", name="runbook_status"),
            nullable=False,
            server_default="fresh",
        ),
        sa.Column("needs_review", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["service_id"], ["services.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_runbooks_service_id", "runbooks", ["service_id"])

    op.create_table(
        "runbook_steps",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("runbook_id", sa.Integer(), nullable=False),
        sa.Column("order", sa.Integer(), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("completed_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["runbook_id"], ["runbooks.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_runbook_steps_runbook_id", "runbook_steps", ["runbook_id"])

    op.create_table(
        "incidents",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column(
            "severity",
            sa.Enum("p1", "p2", "p3", "p4", name="incident_severity"),
            nullable=False,
        ),
        sa.Column("started_at", sa.DateTime(), nullable=False),
        sa.Column("resolved_at", sa.DateTime(), nullable=True),
        sa.Column("service_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["service_id"], ["services.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_incidents_service_id", "incidents", ["service_id"])

    op.create_table(
        "incident_runbooks",
        sa.Column("incident_id", sa.Integer(), nullable=False),
        sa.Column("runbook_id", sa.Integer(), nullable=False),
        sa.Column("was_accurate", sa.Boolean(), nullable=True),
        sa.ForeignKeyConstraint(["incident_id"], ["incidents.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["runbook_id"], ["runbooks.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("incident_id", "runbook_id"),
    )

    op.create_table(
        "action_items",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("incident_id", sa.Integer(), nullable=True),
        sa.Column("runbook_id", sa.Integer(), nullable=True),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column(
            "status",
            sa.Enum("open", "in_progress", "done", name="action_item_status"),
            nullable=False,
            server_default="open",
        ),
        sa.Column("due_date", sa.DateTime(), nullable=True),
        sa.Column("created_at", sa.DateTime(), server_default=sa.func.now(), nullable=False),
        sa.ForeignKeyConstraint(["incident_id"], ["incidents.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["runbook_id"], ["runbooks.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_action_items_incident_id", "action_items", ["incident_id"])
    op.create_index("ix_action_items_runbook_id", "action_items", ["runbook_id"])

    op.create_table(
        "deployments",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("service_id", sa.Integer(), nullable=False),
        sa.Column("version", sa.String(255), nullable=False),
        sa.Column("deployed_at", sa.DateTime(), nullable=False),
        sa.Column("triggered_by", sa.String(255), nullable=True),
        sa.ForeignKeyConstraint(["service_id"], ["services.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_deployments_service_id", "deployments", ["service_id"])


def downgrade() -> None:
    op.drop_table("deployments")
    op.drop_table("action_items")
    op.drop_table("incident_runbooks")
    op.drop_table("incidents")
    op.drop_table("runbook_steps")
    op.drop_table("runbooks")
    op.drop_table("services")
    op.drop_table("users")
    op.execute("DROP TYPE IF EXISTS runbook_status")
    op.execute("DROP TYPE IF EXISTS incident_severity")
    op.execute("DROP TYPE IF EXISTS action_item_status")
