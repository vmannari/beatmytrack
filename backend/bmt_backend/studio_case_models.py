"""Case-owned evidence and append-only support activity; no identity reassignment."""
from sqlalchemy import JSON, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import new_id, now


class StudioCase(Base):
    __tablename__ = "studio_cases"
    __table_args__ = (Index("ix_studio_case_updated", "updated_at", "id"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    player_id: Mapped[str | None] = mapped_column(ForeignKey("players.id"), nullable=True)
    track_id: Mapped[str | None] = mapped_column(ForeignKey("tracks.id"), nullable=True)
    title: Mapped[str] = mapped_column(String(160))
    status: Mapped[str] = mapped_column(String(24), default="open")
    revision: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    updated_at: Mapped[int] = mapped_column(Integer, default=now)


class StudioCaseEvent(Base):
    __tablename__ = "studio_case_events"
    __table_args__ = (Index("ix_studio_case_event", "case_id", "created_at", "id"),
        UniqueConstraint("case_id", "revision", name="uq_studio_case_revision"))
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    case_id: Mapped[str] = mapped_column(ForeignKey("studio_cases.id"))
    actor: Mapped[str] = mapped_column(String(24))
    kind: Mapped[str] = mapped_column(String(24))
    revision: Mapped[int] = mapped_column(Integer, default=0)
    detail: Mapped[dict] = mapped_column(JSON)
    request_hash: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class StudioQuarantine(Base):
    __tablename__ = "studio_quarantines"
    track_id: Mapped[str] = mapped_column(ForeignKey("tracks.id"), primary_key=True)
    case_id: Mapped[str] = mapped_column(ForeignKey("studio_cases.id"))
    audit_id: Mapped[str] = mapped_column(ForeignKey("admin_audit.id"))
