"""Explicit publication requests, separate from the published track inventory."""

from sqlalchemy import JSON, Boolean, ForeignKey, Index, Integer, String, UniqueConstraint, false
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import new_id, now


class PublicationIntent(Base):
    __tablename__ = "publication_intents"
    __table_args__ = (
        UniqueConstraint("player_id", "operation_key"),
        Index("ix_publication_claim", "status", "lease_until", "created_at", "id"),
        Index("ix_publication_evidence", "player_id", "evidence_retired", "status"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), index=True)
    operation_key: Mapped[str] = mapped_column(String(128))
    request_hash: Mapped[str] = mapped_column(String(64))
    authoring_id: Mapped[str] = mapped_column(String(80))
    name: Mapped[str] = mapped_column(String(80))
    content_hash: Mapped[str] = mapped_column(String(64), index=True)
    replay_hash: Mapped[str] = mapped_column(String(64), index=True)
    vehicle_id: Mapped[str] = mapped_column(String(80))
    contract: Mapped[dict] = mapped_column(JSON)
    status: Mapped[str] = mapped_column(String(24), default="queued")
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    lease_until: Mapped[int] = mapped_column(Integer, default=0)
    lease_token: Mapped[str | None] = mapped_column(String(36), nullable=True)
    failure_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    detail: Mapped[str | None] = mapped_column(String(500), nullable=True)
    receipt: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    finished_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    evidence_bytes: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    evidence_retired: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())


class PublicationUpload(Base):
    """An owner-locked reservation precedes external IO and survives process loss."""
    __tablename__ = "publication_uploads"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    operation_key: Mapped[str] = mapped_column(String(128), primary_key=True)
    request_hash: Mapped[str] = mapped_column(String(64))
    content_hash: Mapped[str] = mapped_column(String(64), index=True)
    replay_hash: Mapped[str] = mapped_column(String(64), index=True)
    creator_name: Mapped[str] = mapped_column(String(40))
    evidence_bytes: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[int] = mapped_column(Integer, default=now, index=True)
    lease_until: Mapped[int] = mapped_column(Integer)
    lease_token: Mapped[str] = mapped_column(String(36))
    evidence_retired: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false(), index=True)
