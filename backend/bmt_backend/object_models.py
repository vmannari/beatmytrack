"""Publication/read pins coordinate immutable storage with online garbage collection."""
from sqlalchemy import (
    JSON,
    BigInteger,
    CheckConstraint,
    ForeignKey,
    Index,
    Integer,
    LargeBinary,
    String,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class ObjectPin(Base):
    __tablename__ = "object_pins"
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    expires_at: Mapped[int] = mapped_column(Integer, index=True)


class ObjectGarbageCandidate(Base):
    __tablename__ = "object_garbage_candidates"
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    due_at: Mapped[int] = mapped_column(Integer, index=True)


class ObjectPartition(Base):
    __tablename__ = "object_partitions"
    __table_args__ = (CheckConstraint("pending_bytes >= 0 AND pending_records >= 0"),)
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    pending_bytes: Mapped[int] = mapped_column(Integer, default=0)
    pending_records: Mapped[int] = mapped_column(Integer, default=0)
    lease_until: Mapped[int] = mapped_column(Integer, default=0)
    lease_token: Mapped[str] = mapped_column(String(36), default="")
    batch: Mapped[list] = mapped_column(JSON, default=list)


class ObjectPack(Base):
    __tablename__ = "object_packs"
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    size: Mapped[int] = mapped_column(Integer)
    records: Mapped[int] = mapped_column(Integer)
    dead_bytes: Mapped[int] = mapped_column(Integer, default=0)
    retire_after: Mapped[int] = mapped_column(Integer, default=0, index=True)
    created_at: Mapped[int] = mapped_column(Integer)
    hold_until: Mapped[int] = mapped_column(Integer, default=0)


class PackedObject(Base):
    __tablename__ = "packed_objects"
    __table_args__ = (
        Index("ix_packed_object_pending", "partition", "created_at", "digest",
              postgresql_where=text("pending IS NOT NULL"), sqlite_where=text("pending IS NOT NULL")),
        CheckConstraint('length > 0 AND "offset" >= 0'),
    )
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    partition: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[int] = mapped_column(Integer, index=True)
    pending: Mapped[bytes | None] = mapped_column(LargeBinary, nullable=True)
    pack_digest: Mapped[str | None] = mapped_column(ForeignKey("object_packs.digest"), nullable=True, index=True)
    offset: Mapped[int] = mapped_column(Integer, default=0)
    length: Mapped[int] = mapped_column(Integer)


class ArchiveKey(Base):
    __tablename__ = "private_archive_keys"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    secret: Mapped[bytes] = mapped_column(LargeBinary)
    key_id: Mapped[str] = mapped_column(String(64), unique=True)


class ArchiveChunk(Base):
    __tablename__ = "cost_archive_chunks"
    __table_args__ = (Index("ix_cost_archive_lookup", "kind", "lower", "upper"),)
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
    kind: Mapped[str] = mapped_column(String(16))
    lower: Mapped[str] = mapped_column(String(80))
    upper: Mapped[str] = mapped_column(String(80))
    records: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[int] = mapped_column(Integer)


class CoinArchiveMetric(Base):
    __tablename__ = "coin_archive_metrics"
    at: Mapped[int] = mapped_column(Integer, primary_key=True)
    kind: Mapped[str] = mapped_column(String(16), primary_key=True)
    amount: Mapped[int] = mapped_column(BigInteger)
    count: Mapped[int] = mapped_column(BigInteger)
