import enum
from datetime import datetime

from sqlalchemy import (
    Boolean,
    DateTime,
    Enum as SAEnum,
    ForeignKey,
    Integer,
    String,
    Text,
    func,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class RunbookStatus(str, enum.Enum):
    fresh = "fresh"
    warning = "warning"
    stale = "stale"


class IncidentSeverity(str, enum.Enum):
    p1 = "p1"
    p2 = "p2"
    p3 = "p3"
    p4 = "p4"


class ActionItemStatus(str, enum.Enum):
    open = "open"
    in_progress = "in_progress"
    done = "done"


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )


class Service(Base):
    __tablename__ = "services"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(255), unique=True, nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    owner_team: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )

    runbooks: Mapped[list["Runbook"]] = relationship("Runbook", back_populates="service")
    deployments: Mapped[list["Deployment"]] = relationship("Deployment", back_populates="service")
    incidents: Mapped[list["Incident"]] = relationship("Incident", back_populates="service")


class Runbook(Base):
    __tablename__ = "runbooks"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    content_md: Mapped[str | None] = mapped_column(Text, nullable=True)
    service_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("services.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    last_verified_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    staleness_days: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    status: Mapped[RunbookStatus] = mapped_column(
        SAEnum(RunbookStatus, name="runbook_status"),
        nullable=False,
        default=RunbookStatus.fresh,
    )
    needs_review: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now(), onupdate=func.now()
    )

    service: Mapped["Service"] = relationship("Service", back_populates="runbooks")
    steps: Mapped[list["RunbookStep"]] = relationship(
        "RunbookStep",
        back_populates="runbook",
        order_by="RunbookStep.order",
        cascade="all, delete-orphan",
    )
    incident_links: Mapped[list["IncidentRunbook"]] = relationship(
        "IncidentRunbook", back_populates="runbook"
    )
    action_items: Mapped[list["ActionItem"]] = relationship(
        "ActionItem", back_populates="runbook"
    )


class RunbookStep(Base):
    __tablename__ = "runbook_steps"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    runbook_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("runbooks.id", ondelete="CASCADE"), nullable=False, index=True
    )
    order: Mapped[int] = mapped_column(Integer, nullable=False)
    description: Mapped[str] = mapped_column(Text, nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    runbook: Mapped["Runbook"] = relationship("Runbook", back_populates="steps")


class Incident(Base):
    __tablename__ = "incidents"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    severity: Mapped[IncidentSeverity] = mapped_column(
        SAEnum(IncidentSeverity, name="incident_severity"), nullable=False
    )
    started_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    service_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("services.id", ondelete="RESTRICT"), nullable=False, index=True
    )

    service: Mapped["Service"] = relationship("Service", back_populates="incidents")
    runbook_links: Mapped[list["IncidentRunbook"]] = relationship(
        "IncidentRunbook", back_populates="incident", cascade="all, delete-orphan"
    )
    action_items: Mapped[list["ActionItem"]] = relationship(
        "ActionItem", back_populates="incident"
    )


class IncidentRunbook(Base):
    __tablename__ = "incident_runbooks"

    incident_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("incidents.id", ondelete="CASCADE"), primary_key=True
    )
    runbook_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("runbooks.id", ondelete="CASCADE"), primary_key=True
    )
    was_accurate: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    incident: Mapped["Incident"] = relationship("Incident", back_populates="runbook_links")
    runbook: Mapped["Runbook"] = relationship("Runbook", back_populates="incident_links")


class ActionItem(Base):
    __tablename__ = "action_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    incident_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("incidents.id", ondelete="SET NULL"), nullable=True, index=True
    )
    runbook_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("runbooks.id", ondelete="SET NULL"), nullable=True, index=True
    )
    description: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[ActionItemStatus] = mapped_column(
        SAEnum(ActionItemStatus, name="action_item_status"),
        nullable=False,
        default=ActionItemStatus.open,
    )
    due_date: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime, nullable=False, server_default=func.now()
    )

    incident: Mapped["Incident | None"] = relationship("Incident", back_populates="action_items")
    runbook: Mapped["Runbook | None"] = relationship("Runbook", back_populates="action_items")


class Deployment(Base):
    __tablename__ = "deployments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    service_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("services.id", ondelete="RESTRICT"), nullable=False, index=True
    )
    version: Mapped[str] = mapped_column(String(255), nullable=False)
    deployed_at: Mapped[datetime] = mapped_column(DateTime, nullable=False)
    triggered_by: Mapped[str | None] = mapped_column(String(255), nullable=True)

    service: Mapped["Service"] = relationship("Service", back_populates="deployments")
