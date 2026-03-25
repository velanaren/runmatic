from datetime import datetime
from typing import Any

from pydantic import BaseModel, EmailStr, Field

from app.models import ActionItemStatus, IncidentSeverity, RunbookStatus

# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ---------------------------------------------------------------------------
# Service
# ---------------------------------------------------------------------------


class ServiceCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str | None = None
    owner_team: str | None = None


class ServiceResponse(BaseModel):
    id: int
    name: str
    description: str | None
    owner_team: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class ServiceDetailResponse(ServiceResponse):
    runbook_count: int = 0
    stale_count: int = 0


# ---------------------------------------------------------------------------
# Runbook
# ---------------------------------------------------------------------------


class RunbookStepCreate(BaseModel):
    order: int = Field(ge=1)
    description: str = Field(min_length=1)


class RunbookStepResponse(BaseModel):
    id: int
    runbook_id: int
    order: int
    description: str
    completed_at: datetime | None

    model_config = {"from_attributes": True}


class RunbookCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    content_md: str | None = None
    service_id: int
    steps: list[RunbookStepCreate] = Field(default_factory=list)


class RunbookUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=255)
    content_md: str | None = None


class RunbookResponse(BaseModel):
    id: int
    title: str
    content_md: str | None
    service_id: int
    service_name: str | None = None
    last_verified_at: datetime | None
    staleness_days: int
    status: RunbookStatus
    needs_review: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class RunbookDetailResponse(RunbookResponse):
    steps: list[RunbookStepResponse] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Incident
# ---------------------------------------------------------------------------


class IncidentCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    severity: IncidentSeverity
    started_at: datetime
    service_id: int


class IncidentResolve(BaseModel):
    resolved_at: datetime | None = None


class IncidentLinkRunbook(BaseModel):
    runbook_id: int
    was_accurate: bool | None = None


class IncidentRunbookResponse(BaseModel):
    runbook_id: int
    runbook_title: str | None = None
    was_accurate: bool | None

    model_config = {"from_attributes": True}


class IncidentResponse(BaseModel):
    id: int
    title: str
    severity: IncidentSeverity
    started_at: datetime
    resolved_at: datetime | None
    service_id: int
    service_name: str | None = None

    model_config = {"from_attributes": True}


class IncidentDetailResponse(IncidentResponse):
    linked_runbooks: list[IncidentRunbookResponse] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Action Items
# ---------------------------------------------------------------------------


class ActionItemCreate(BaseModel):
    description: str = Field(min_length=1)
    incident_id: int | None = None
    runbook_id: int | None = None
    due_date: datetime | None = None


class ActionItemUpdate(BaseModel):
    status: ActionItemStatus | None = None
    description: str | None = Field(default=None, min_length=1)
    due_date: datetime | None = None


class ActionItemResponse(BaseModel):
    id: int
    description: str
    status: ActionItemStatus
    incident_id: int | None
    runbook_id: int | None
    due_date: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# Webhook
# ---------------------------------------------------------------------------


class DeploymentWebhookPayload(BaseModel):
    service_name: str = Field(min_length=1)
    version: str = Field(min_length=1)
    triggered_by: str | None = None
    deployed_at: datetime | None = None


class DeploymentWebhookResponse(BaseModel):
    accepted: bool
    job_id: str
    message: str


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------


class HealthResponse(BaseModel):
    status: str
    db: str
    cache: str
    details: dict[str, Any] = Field(default_factory=dict)


# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------


class DashboardStats(BaseModel):
    runbook_total: int
    fresh_count: int
    warning_count: int
    stale_count: int
    needs_review_count: int
    open_incidents: int
    open_action_items: int
    services_total: int
