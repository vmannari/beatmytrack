"""Versioned analytical facts and Studio-owned operations, never race authority."""

from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    CheckConstraint,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import new_id, now


class AnalysisState(Base):
    __tablename__ = "studio_analysis_state"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    version: Mapped[int] = mapped_column(Integer, default=1)
    started_at: Mapped[int] = mapped_column(Integer, default=now)
    processed_through: Mapped[int | None] = mapped_column(Integer, nullable=True)
    latest_client_at: Mapped[int | None] = mapped_column(Integer, nullable=True)


class AnalysisPerson(Base):
    __tablename__ = "studio_analysis_people"
    __table_args__ = (Index("ix_analysis_cohort", "first_at", "player_id"),)
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    first_at: Mapped[int] = mapped_column(Integer)
    first_build: Mapped[str] = mapped_column(String(80), default="")
    first_platform: Mapped[str] = mapped_column(String(12), default="")
    first_mode: Mapped[str] = mapped_column(String(24), default="")
    artificial: Mapped[bool] = mapped_column(Boolean, default=False)
    first_client_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    journey: Mapped[dict] = mapped_column(JSON, default=dict)


class AnalysisDay(Base):
    __tablename__ = "studio_analysis_days"
    __table_args__ = (
        Index("ix_analysis_player_day", "player_id", "day"),
        Index("ix_analysis_build_day", "build_id", "platform", "day"),
    )
    day: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    dimension: Mapped[str] = mapped_column(String(64), primary_key=True)
    build_id: Mapped[str] = mapped_column(String(80), default="")
    platform: Mapped[str] = mapped_column(String(12), default="")
    mode: Mapped[str] = mapped_column(String(24), default="")
    device_model: Mapped[str] = mapped_column(String(80), default="")
    os_version: Mapped[str] = mapped_column(String(80), default="")
    renderer: Mapped[str] = mapped_column(String(20), default="")
    artificial: Mapped[bool] = mapped_column(Boolean, default=False)
    counters: Mapped[dict] = mapped_column(JSON, default=dict)
    first_at: Mapped[int] = mapped_column(Integer)
    last_at: Mapped[int] = mapped_column(Integer)


class AnalysisSession(Base):
    __tablename__ = "studio_analysis_sessions"
    __table_args__ = (Index("ix_analysis_session_date", "first_at", "player_id"),)
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    session_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    build_id: Mapped[str] = mapped_column(String(80), default="")
    platform: Mapped[str] = mapped_column(String(12), default="")
    first_at: Mapped[int] = mapped_column(Integer)
    last_at: Mapped[int] = mapped_column(Integer)
    foreground_ms: Mapped[int] = mapped_column(BigInteger, default=0)
    starts: Mapped[int] = mapped_column(Integer, default=0)
    finishes: Mapped[int] = mapped_column(Integer, default=0)


class StudioStaff(Base):
    __tablename__ = "studio_staff"
    id: Mapped[str] = mapped_column(String(24), primary_key=True)
    display_name: Mapped[str] = mapped_column(String(100))
    role: Mapped[str] = mapped_column(String(16))
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    last_seen_at: Mapped[int] = mapped_column(Integer, default=now)


class StudioIncident(Base):
    __tablename__ = "studio_incidents"
    __table_args__ = (
        UniqueConstraint("source", "signal", "occurrence"),
        Index("ix_incident_state_time", "state", "opened_at", "id"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    source: Mapped[str] = mapped_column(String(64))
    signal: Mapped[str] = mapped_column(String(64))
    occurrence: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(160))
    severity: Mapped[str] = mapped_column(String(16))
    state: Mapped[str] = mapped_column(String(16), default="open")
    revision: Mapped[int] = mapped_column(Integer, default=0)
    opened_at: Mapped[int] = mapped_column(Integer)
    last_seen_at: Mapped[int] = mapped_column(Integer)
    recovered_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    closed_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    assignee: Mapped[str] = mapped_column(String(24), default="")
    evidence: Mapped[dict] = mapped_column(JSON, default=dict)


class StudioSignal(Base):
    __tablename__ = "studio_signals"
    source: Mapped[str] = mapped_column(String(64), primary_key=True)
    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    occurrence: Mapped[int] = mapped_column(Integer, default=0)
    active: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    incident_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    observed_at: Mapped[int] = mapped_column(Integer)
    suppressed_until: Mapped[int] = mapped_column(Integer, default=0)
    suppression_reason: Mapped[str] = mapped_column(String(500), default="")


class StudioIncidentEvent(Base):
    __tablename__ = "studio_incident_events"
    __table_args__ = (Index("ix_incident_history", "incident_id", "created_at", "id"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    incident_id: Mapped[str] = mapped_column(String(36))
    actor: Mapped[str] = mapped_column(String(24))
    kind: Mapped[str] = mapped_column(String(24))
    revision: Mapped[int] = mapped_column(Integer)
    detail: Mapped[dict] = mapped_column(JSON)
    request_hash: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class StudioDelivery(Base):
    __tablename__ = "studio_deliveries"
    __table_args__ = (Index("ix_studio_delivery_due", "state", "next_attempt_at", "id"),)
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    incident_id: Mapped[str] = mapped_column(String(36))
    event_id: Mapped[str] = mapped_column(String(36))
    state: Mapped[str] = mapped_column(String(16), default="pending")
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    next_attempt_at: Mapped[int] = mapped_column(Integer, default=0)
    lease_until: Mapped[int] = mapped_column(Integer, default=0)
    lease_token: Mapped[str | None] = mapped_column(String(36), nullable=True)
    payload: Mapped[dict] = mapped_column(JSON)
    last_error: Mapped[str] = mapped_column(String(64), default="")
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class StudioObservation(Base):
    __tablename__ = "studio_observations"
    __table_args__ = (Index("ix_studio_observation_time", "observed_at", "source"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    source: Mapped[str] = mapped_column(String(64))
    observed_at: Mapped[int] = mapped_column(Integer)
    received_at: Mapped[int] = mapped_column(Integer, default=now)
    payload_hash: Mapped[str] = mapped_column(String(64))
    values: Mapped[dict] = mapped_column(JSON)


class StudioRelease(Base):
    __tablename__ = "studio_releases"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    build_id: Mapped[str] = mapped_column(String(80), unique=True)
    name: Mapped[str] = mapped_column(String(100))
    notes: Mapped[str] = mapped_column(String(500), default="")
    state: Mapped[str] = mapped_column(String(16), default="testing")
    revision: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    actor: Mapped[str] = mapped_column(String(24))


class StudioFinanceEvent(Base):
    __tablename__ = "studio_finance_events"
    __table_args__ = (
        UniqueConstraint("provider", "reference"),
        Index("ix_finance_period", "occurred_at", "currency", "kind"),
        Index("ix_finance_player", "player_id", "occurred_at"),
        Index("ix_studio_finance_received", "received_at"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    provider: Mapped[str] = mapped_column(String(24))
    reference: Mapped[str] = mapped_column(String(64))
    player_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    purchase_id: Mapped[str | None] = mapped_column(String(96), nullable=True)
    kind: Mapped[str] = mapped_column(String(24))
    basis: Mapped[str] = mapped_column(String(24))
    currency: Mapped[str] = mapped_column(String(3))
    amount_micros: Mapped[int] = mapped_column(BigInteger)
    occurred_at: Mapped[int] = mapped_column(Integer)
    received_at: Mapped[int] = mapped_column(Integer, default=now)
    dimensions: Mapped[dict] = mapped_column(JSON, default=dict)
    payload_hash: Mapped[str] = mapped_column(String(64))


class StudioExperiment(Base):
    __tablename__ = "studio_experiments"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    name: Mapped[str] = mapped_column(String(100))
    state: Mapped[str] = mapped_column(String(16), default="draft")
    revision: Mapped[int] = mapped_column(Integer, default=0)
    primary_metric: Mapped[str] = mapped_column(String(40))
    followup_days: Mapped[int] = mapped_column(Integer, default=7)
    minimum_per_variant: Mapped[int] = mapped_column(Integer, default=500)
    allocation: Mapped[dict] = mapped_column(JSON)
    variants: Mapped[dict] = mapped_column(JSON)
    salt: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    started_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    stopped_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    actor: Mapped[str] = mapped_column(String(24))


class StudioCoinEntry(Base):
    __tablename__ = "studio_coin_entries"
    __table_args__ = (
        UniqueConstraint("player_id", "reference"),
        Index("ix_studio_coin_period", "created_at", "player_id"),
    )
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    player_id: Mapped[str] = mapped_column(String(36))
    reference: Mapped[str] = mapped_column(String(100))
    kind: Mapped[str] = mapped_column(String(16))
    amount: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    detail: Mapped[dict] = mapped_column(JSON, default=dict)


class StudioAssignment(Base):
    __tablename__ = "studio_assignments"
    experiment_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    variant: Mapped[str] = mapped_column(String(24))
    revision: Mapped[int] = mapped_column(Integer)
    assigned_at: Mapped[int] = mapped_column(Integer, default=now)
    exposed_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    exposure_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    __table_args__ = (Index("ix_experiment_exposure", "experiment_id", "exposed_at", "player_id"),)


class StudioSavedView(Base):
    __tablename__ = "studio_saved_views"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    owner: Mapped[str] = mapped_column(String(24), index=True)
    name: Mapped[str] = mapped_column(String(100))
    route: Mapped[str] = mapped_column(String(40))
    filters: Mapped[dict] = mapped_column(JSON)
    revision: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[int] = mapped_column(Integer, default=now)


class StudioCaseTriage(Base):
    __tablename__ = "studio_case_triage"
    case_id: Mapped[str] = mapped_column(ForeignKey("studio_cases.id"), primary_key=True)
    assignee: Mapped[str] = mapped_column(String(24), default="")
    priority: Mapped[str] = mapped_column(String(16), default="normal")
    due_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    incident_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    revision: Mapped[int] = mapped_column(Integer, default=0)
    __table_args__ = (CheckConstraint("priority IN ('normal','high','urgent')"),)
