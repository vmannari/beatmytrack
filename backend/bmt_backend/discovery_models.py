"""Incremental discovery history and bounded, expiring browsing state.

History stores changes, not copies of a catalogue per query or generation.
Track UUID prefixes partition writers; each partition publishes its own epoch.
"""
from sqlalchemy import JSON, BigInteger, Boolean, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base

PARTITIONS = 16
LIFETIME = 1800
WINDOW = 7 * 86400


class DiscoveryPartition(Base):
    __tablename__ = "discovery_partitions"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    epoch: Mapped[int] = mapped_column(BigInteger, default=0)
    slots: Mapped[int] = mapped_column(BigInteger, default=0)
    checked_at: Mapped[int] = mapped_column(BigInteger, default=0)
    audit_at: Mapped[int] = mapped_column(BigInteger, default=0)
    cursor: Mapped[str] = mapped_column(String(36), default="")
    ready: Mapped[bool] = mapped_column(Boolean, default=False)


class DiscoveryHead(Base):
    __tablename__ = "discovery_heads"
    track_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    partition: Mapped[int] = mapped_column(Integer)
    slot: Mapped[int] = mapped_column(BigInteger)
    epoch: Mapped[int] = mapped_column(BigInteger, default=0)
    popularity: Mapped[int] = mapped_column(BigInteger, default=0)
    due_at: Mapped[int] = mapped_column(BigInteger, default=0)
    __table_args__ = (UniqueConstraint("partition", "slot"), Index("ix_discovery_head_due", "partition", "due_at"))


class DiscoveryEntry(Base):
    __tablename__ = "discovery_entries"
    track_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    epoch: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    partition: Mapped[int] = mapped_column(Integer)
    until: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    retired_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    version_id: Mapped[str] = mapped_column(String(36))
    owner_id: Mapped[str] = mapped_column(String(36))
    visible: Mapped[bool] = mapped_column(Boolean)
    official: Mapped[bool] = mapped_column(Boolean)
    name: Mapped[str] = mapped_column(String(80))
    creator: Mapped[str] = mapped_column(String(40))
    # Unicode lowercase can expand a source character into two code points.
    name_key: Mapped[str] = mapped_column(String(160))
    creator_key: Mapped[str] = mapped_column(String(80))
    theme: Mapped[str] = mapped_column(String(40))
    published_at: Mapped[int] = mapped_column(BigInteger)
    created_at: Mapped[int] = mapped_column(BigInteger)
    rating_sum: Mapped[int] = mapped_column(BigInteger)
    rating_count: Mapped[int] = mapped_column(BigInteger)
    rated: Mapped[bool] = mapped_column(Boolean)
    score: Mapped[int] = mapped_column(BigInteger)
    finishers: Mapped[int] = mapped_column(BigInteger)
    popularity: Mapped[int] = mapped_column(BigInteger)
    __table_args__ = (
        Index("ix_discovery_entry_new", "partition", "published_at", "track_id"),
        Index("ix_discovery_entry_theme", "partition", "theme", "published_at", "track_id"),
        Index("ix_discovery_entry_mix", "partition", "official", "published_at", "track_id"),
        Index("ix_discovery_entry_name", "partition", "name_key", "track_id"),
        Index("ix_discovery_entry_creator", "partition", "creator_key", "name_key", "track_id"),
        Index("ix_discovery_entry_score", "partition", "rated", "score", "published_at", "track_id"),
        Index("ix_discovery_entry_plays", "partition", "finishers", "published_at", "track_id"),
        Index("ix_discovery_entry_popular", "partition", "popularity", "published_at", "track_id"),
        Index("ix_discovery_entry_retired", "retired_at", "track_id", "epoch"),
        Index("ix_discovery_entry_version", "version_id", "epoch"),
        Index("ix_discovery_entry_owner", "owner_id", "track_id", "epoch"),
    )


class DiscoveryChange(Base):
    __tablename__ = "discovery_changes"
    # INTEGER is SQLite's auto-increment rowid; PostgreSQL uses BIGSERIAL.
    id: Mapped[int] = mapped_column(BigInteger().with_variant(Integer, "sqlite"), primary_key=True, autoincrement=True)
    partition: Mapped[int] = mapped_column(Integer)
    kind: Mapped[str] = mapped_column(String(12))
    target: Mapped[str] = mapped_column(String(36))
    player_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    run_id: Mapped[str | None] = mapped_column(String(36), nullable=True, unique=True)
    finished_at: Mapped[int] = mapped_column(BigInteger, default=0)
    created_at: Mapped[int] = mapped_column(BigInteger)
    processed_at: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    __table_args__ = (Index("ix_discovery_change_claim", "partition", "processed_at", "id"),
                      Index("ix_discovery_change_retire", "processed_at", "id"),
                      Index("ix_discovery_change_player", "player_id", "id"))


class DiscoveryDriver(Base):
    __tablename__ = "discovery_drivers"
    track_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    partition: Mapped[int] = mapped_column(Integer)
    last_at: Mapped[int] = mapped_column(BigInteger)
    expires_at: Mapped[int] = mapped_column(BigInteger)
    counted: Mapped[bool] = mapped_column(Boolean)
    __table_args__ = (Index("ix_discovery_driver_expire", "partition", "expires_at", "track_id", "player_id"),
                      Index("ix_discovery_driver_player", "player_id", "track_id"))


class DiscoveryOwnerJob(Base):
    __tablename__ = "discovery_owner_jobs"
    partition: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    cursor: Mapped[str] = mapped_column(String(36), default="")
    phase: Mapped[int] = mapped_column(Integer, default=0)


class DiscoveryBootstrap(Base):
    __tablename__ = "discovery_bootstrap"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    finished_at: Mapped[int] = mapped_column(BigInteger, default=0)
    run_id: Mapped[str] = mapped_column(String(36), default="")
    ready: Mapped[bool] = mapped_column(Boolean, default=False)


class DiscoveryCollection(Base):
    __tablename__ = "discovery_collections"
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    scope: Mapped[str] = mapped_column(String(64))
    expires_at: Mapped[int] = mapped_column(BigInteger)
    __table_args__ = (Index("ix_discovery_collection_expire", "expires_at", "id"),
                      Index("ix_discovery_collection_scope", "scope", "expires_at"))


class DiscoveryMember(Base):
    __tablename__ = "discovery_members"
    collection_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    kind: Mapped[str] = mapped_column(String(8), primary_key=True)
    # Typed identifier: block members contain creator IDs; other kinds tracks.
    track_id: Mapped[str] = mapped_column(String(80), primary_key=True)


class DiscoverySession(Base):
    __tablename__ = "discovery_sessions"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    scope: Mapped[str] = mapped_column(String(64))
    expires_at: Mapped[int] = mapped_column(BigInteger)
    created_at: Mapped[int] = mapped_column(BigInteger)
    secret: Mapped[str] = mapped_column(String(64))
    query: Mapped[dict] = mapped_column(JSON)
    epochs: Mapped[list] = mapped_column(JSON)
    slots: Mapped[list] = mapped_column(JSON)
    collection_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    __table_args__ = (Index("ix_discovery_session_expire", "expires_at", "id"),
                      Index("ix_discovery_session_scope", "scope", "expires_at"))


class DiscoveryBoundary(Base):
    """Small checkpoints only for pages actually visited; no track-ID vectors."""
    __tablename__ = "discovery_boundaries"
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    session_id: Mapped[str] = mapped_column(String(36))
    expires_at: Mapped[int] = mapped_column(BigInteger)
    positions: Mapped[dict] = mapped_column(JSON)
    phase: Mapped[int] = mapped_column(Integer)
    previous_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    anchor_version: Mapped[str | None] = mapped_column(String(36), nullable=True)
    __table_args__ = (Index("ix_discovery_boundary_expire", "expires_at", "id"),
                      Index("ix_discovery_boundary_session", "session_id", "id"))
