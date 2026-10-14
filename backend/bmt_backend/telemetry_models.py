"""Pseudonymous product observations and bounded prepared reporting facts."""

from sqlalchemy import JSON, Boolean, Index, Integer, String, text
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class ProductEvent(Base):
    __tablename__ = "product_events"
    __table_args__ = (Index("ix_product_pending", "processed_at", "received_at", "id"),
        Index("ix_product_pending_order", "received_at", "id",
            sqlite_where=text("processed_at IS NULL"), postgresql_where=text("processed_at IS NULL")),
        Index("ix_product_client_cleanup", "received_at", "id",
            sqlite_where=text("source='client' AND processed_at IS NOT NULL"),
            postgresql_where=text("source='client' AND processed_at IS NOT NULL")),
        Index("ix_product_server_compact", "received_at", "id",
            sqlite_where=text("source='server' AND processed_at IS NOT NULL AND compacted=false"),
            postgresql_where=text("source='server' AND processed_at IS NOT NULL AND compacted=false")),
        Index("ix_product_network_failures", "occurred_at", "id",
            sqlite_where=text("source='client' AND name='network_failure'"),
            postgresql_where=text("source='client' AND name='network_failure'")))
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    client_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    entity_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    player_id: Mapped[str] = mapped_column(String(36))
    is_test_driver: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    source: Mapped[str] = mapped_column(String(8))
    name: Mapped[str] = mapped_column(String(32))
    occurred_at: Mapped[int] = mapped_column(Integer)
    received_at: Mapped[int] = mapped_column(Integer)
    session_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    install_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    seq: Mapped[int | None] = mapped_column(Integer, nullable=True)
    monotonic_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    build_id: Mapped[str] = mapped_column(String(80), default="")
    platform: Mapped[str] = mapped_column(String(12), default="")
    clock_quality: Mapped[str] = mapped_column(String(16), default="unknown")
    payload_hash: Mapped[str] = mapped_column(String(64))
    properties: Mapped[dict] = mapped_column(JSON, default=dict)
    processed_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    compacted: Mapped[bool] = mapped_column(Boolean, default=False)


class ProductPlayerDay(Base):
    __tablename__ = "product_player_days"
    day: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    __table_args__ = (Index("ix_product_activity_player", "player_id", "day"),)


class ProductMetric(Base):
    __tablename__ = "product_metrics"
    day: Mapped[int] = mapped_column(Integer, primary_key=True)
    key: Mapped[str] = mapped_column(String(48), primary_key=True)
    dimension: Mapped[str] = mapped_column(String(32), primary_key=True, default="")
    value: Mapped[int] = mapped_column(Integer, default=0)


class ProductProfile(Base):
    __tablename__ = "product_profiles"
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    first_activity_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    milestones: Mapped[list] = mapped_column(JSON, default=list)
    projection: Mapped[dict] = mapped_column(JSON, default=dict)
    truncated: Mapped[bool] = mapped_column(Boolean, default=False)
    quality: Mapped[dict] = mapped_column(JSON, default=dict)
    truncations: Mapped[dict] = mapped_column(JSON, default=dict)


class ProductState(Base):
    __tablename__ = "product_state"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    collection_started_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    processed_through: Mapped[int | None] = mapped_column(Integer, nullable=True)
    latest_receipt_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    observed_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    pending_events: Mapped[int] = mapped_column(Integer, default=0)
    processed_events: Mapped[int] = mapped_column(Integer, default=0)
    truncated_profiles: Mapped[int] = mapped_column(Integer, default=0)
    pending_clients: Mapped[int] = mapped_column(Integer, default=0)
    pending_capped: Mapped[bool] = mapped_column(Boolean, default=False)
    retained_from_day: Mapped[int | None] = mapped_column(Integer, nullable=True)
    fact_days: Mapped[int] = mapped_column(Integer, default=180)


class ProductPublication(Base):
    __tablename__ = "product_publications"
    __table_args__ = (Index("ix_product_publication_age", "published_at"),)
    version_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    owner_id: Mapped[str] = mapped_column(String(36))
    published_at: Mapped[int] = mapped_column(Integer)
    observed: Mapped[bool] = mapped_column(Boolean, default=False)
    first_external_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
