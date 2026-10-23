"""Independent intake, projection and reporting ownership for telemetry v2."""
from sqlalchemy import JSON, BigInteger, Boolean, CheckConstraint, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class TelemetryControl(Base):
    __tablename__ = "telemetry_control"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    active: Mapped[bool] = mapped_column(Boolean, default=False)
    ready: Mapped[bool] = mapped_column(Boolean, default=False)
    capacity: Mapped[int] = mapped_column(Integer, default=50000)
    baseline_processed: Mapped[int] = mapped_column(BigInteger, default=0)
    baseline_truncated: Mapped[int] = mapped_column(BigInteger, default=0)
    barrier: Mapped[dict] = mapped_column(JSON, default=dict)
    published_at: Mapped[int] = mapped_column(BigInteger, default=0)
    maintenance_at: Mapped[int] = mapped_column(BigInteger, default=0)
    person_cursor: Mapped[str] = mapped_column(String(36), default="")


class TelemetryCredit(Base):
    __tablename__ = "telemetry_credits"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    capacity: Mapped[int] = mapped_column(Integer)
    free: Mapped[int] = mapped_column(Integer)
    __table_args__ = (Index("ix_telemetry_free_credit", "free", "id"),
        CheckConstraint("capacity >= 0 AND free >= 0 AND free <= capacity", name="ck_telemetry_credit_bounds"))


class TelemetryIntake(Base):
    __tablename__ = "telemetry_intake"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    position: Mapped[int] = mapped_column(BigInteger, default=0)
    events: Mapped[int] = mapped_column(BigInteger, default=0)
    clients: Mapped[int] = mapped_column(BigInteger, default=0)
    latest: Mapped[int] = mapped_column(BigInteger, default=0)


class TelemetryActor(Base):
    __tablename__ = "telemetry_actors"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    position: Mapped[int] = mapped_column(BigInteger, default=0)
    revision: Mapped[int] = mapped_column(BigInteger, default=0)
    serviced_at: Mapped[int] = mapped_column(BigInteger, default=0)
    first_activity: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    latest_client_at: Mapped[int] = mapped_column(BigInteger, default=0)
    truncated: Mapped[int] = mapped_column(BigInteger, default=0)
    retry_after: Mapped[int] = mapped_column(BigInteger, default=0)
    failures: Mapped[int] = mapped_column(BigInteger, default=0)
    metric_owner: Mapped[int | None] = mapped_column(Integer, nullable=True)
    metric_revision: Mapped[int] = mapped_column(BigInteger, default=0)


class TelemetryFinish(Base):
    __tablename__ = "telemetry_finishes"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    position: Mapped[int] = mapped_column(BigInteger, default=0)
    events: Mapped[int] = mapped_column(BigInteger, default=0)
    clients: Mapped[int] = mapped_column(BigInteger, default=0)
    processed: Mapped[int] = mapped_column(BigInteger, default=0)


class TelemetrySharedIntake(Base):
    __tablename__ = "telemetry_shared_intake"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    position: Mapped[int] = mapped_column(BigInteger, default=0)


class TelemetryShared(Base):
    __tablename__ = "telemetry_shared"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    position: Mapped[int] = mapped_column(BigInteger, default=0)
    revision: Mapped[int] = mapped_column(BigInteger, default=0)
    serviced_at: Mapped[int] = mapped_column(BigInteger, default=0)
    retry_after: Mapped[int] = mapped_column(BigInteger, default=0)
    failures: Mapped[int] = mapped_column(BigInteger, default=0)


class TelemetryWork(Base):
    __tablename__ = "telemetry_work"
    event_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    partition: Mapped[int] = mapped_column(Integer)
    position: Mapped[int] = mapped_column(BigInteger)
    kind: Mapped[str] = mapped_column(String(16))
    key: Mapped[str] = mapped_column(String(64))
    player_id: Mapped[str] = mapped_column(String(36), index=True)
    owner_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    __table_args__ = (Index("ix_telemetry_work_order", "partition", "position"),)


class TelemetryMetric(Base):
    __tablename__ = "telemetry_metric_partials"
    owner: Mapped[int] = mapped_column(Integer, primary_key=True)
    day: Mapped[int] = mapped_column(Integer, primary_key=True)
    key: Mapped[str] = mapped_column(String(48), primary_key=True)
    dimension: Mapped[str] = mapped_column(String(32), primary_key=True)
    value: Mapped[int] = mapped_column(BigInteger)
    revision: Mapped[int] = mapped_column(BigInteger)
    __table_args__ = (Index("ix_telemetry_metric_revision", "owner", "revision"),
        Index("ix_telemetry_metric_expiry", "day", "owner"))


class TelemetryMetricFold(Base):
    __tablename__ = "telemetry_metric_folds"
    owner: Mapped[int] = mapped_column(Integer, primary_key=True)
    day: Mapped[int] = mapped_column(Integer, primary_key=True)
    key: Mapped[str] = mapped_column(String(48), primary_key=True)
    dimension: Mapped[str] = mapped_column(String(32), primary_key=True)
    value: Mapped[int] = mapped_column(BigInteger)


class TelemetryRollup(Base):
    __tablename__ = "telemetry_rollups"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    revision: Mapped[int] = mapped_column(BigInteger, default=0)
    serviced_at: Mapped[int] = mapped_column(BigInteger, default=0)


class TelemetryErasure(Base):
    __tablename__ = "telemetry_erasure"
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    cursor: Mapped[str] = mapped_column(String(36), default="")
    done: Mapped[bool] = mapped_column(Boolean, default=False)
