"""Race package receipts and prepared diagnostic aggregates; no score authority."""
from sqlalchemy import JSON, BigInteger, Boolean, Index, Integer, String
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class RaceStatisticsReceipt(Base):
    __tablename__ = "race_statistics_receipts"
    __table_args__ = (Index("ix_race_statistics_receipt_age", "received_at", "player_id", "race_id"),)
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    race_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    event_id: Mapped[str] = mapped_column(String(36))
    payload_hash: Mapped[str] = mapped_column(String(64))
    received_at: Mapped[int] = mapped_column(Integer)


class RaceStatisticsDay(Base):
    __tablename__ = "race_statistics_days"
    __table_args__ = (
        Index("ix_race_statistics_version", "track_version_id", "day", "device_model", "os_version"),
        Index("ix_race_statistics_device", "device_model", "os_version", "day"),
    )
    day: Mapped[int] = mapped_column(Integer, primary_key=True)
    dimension: Mapped[str] = mapped_column(String(64), primary_key=True)
    track_version_id: Mapped[str] = mapped_column(String(36), default="")
    build_id: Mapped[str] = mapped_column(String(80))
    platform: Mapped[str] = mapped_column(String(12))
    device_class: Mapped[str] = mapped_column(String(24))
    device_model: Mapped[str] = mapped_column(String(80))
    os_version: Mapped[str] = mapped_column(String(80))
    outcome: Mapped[str] = mapped_column(String(16))
    render_context_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    render_context: Mapped[dict | None] = mapped_column(JSON().with_variant(JSONB(), "postgresql"), nullable=True)
    render_context_changed: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    races: Mapped[int] = mapped_column(BigInteger, default=0)
    elapsed_ms: Mapped[int] = mapped_column(BigInteger, default=0)
    latest_received_at: Mapped[int] = mapped_column(BigInteger, default=0)
    frame_buckets: Mapped[list] = mapped_column(JSON, default=lambda: [0] * 8)
    position_samples: Mapped[int] = mapped_column(BigInteger, default=0)
    dropped_samples: Mapped[int] = mapped_column(BigInteger, default=0)
    aggregate_dropped_samples: Mapped[int] = mapped_column(BigInteger, default=0)
    cells: Mapped[dict] = mapped_column(JSON, default=dict)
    segments: Mapped[dict] = mapped_column(JSON, default=dict)

