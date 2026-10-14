"""Prepared bounded network observations, never availability or score authority."""
from sqlalchemy import JSON, BigInteger, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class NetworkHealthDay(Base):
    __tablename__ = "network_health_days"
    __table_args__ = (Index("ix_network_health_scope", "platform", "build_id", "day"),)
    day: Mapped[int] = mapped_column(Integer, primary_key=True)
    dimension: Mapped[str] = mapped_column(String(64), primary_key=True)
    platform: Mapped[str] = mapped_column(String(12))
    build_id: Mapped[str] = mapped_column(String(80))
    category: Mapped[str] = mapped_column(String(24))
    device_model: Mapped[str] = mapped_column(String(80))
    os_version: Mapped[str] = mapped_column(String(80))
    counters: Mapped[dict] = mapped_column(JSON, default=dict)
    buckets: Mapped[dict] = mapped_column(JSON, default=dict)
    latest_received_at: Mapped[int] = mapped_column(BigInteger, default=0)
