"""Invitation-scoped competitions; timing is written only by verification."""
from sqlalchemy import JSON, Boolean, CheckConstraint, ForeignKey, Index, Integer, String, false
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import new_id, now


class Challenge(Base):
    __tablename__ = "challenges"
    __table_args__ = (Index("ix_challenge_creator_recent", "creator_id", "created_at"),
                      CheckConstraint("member_count >= 1 AND member_count <= 20"))
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    code: Mapped[str] = mapped_column(String(16), unique=True)
    creator_id: Mapped[str] = mapped_column(ForeignKey("players.id"))
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"))
    mode: Mapped[str] = mapped_column(String(8))
    target_run_id: Mapped[str | None] = mapped_column(ForeignKey("runs.id"), nullable=True)
    target_ticks: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    ends_at: Mapped[int] = mapped_column(Integer)
    member_count: Mapped[int] = mapped_column(Integer, default=1)
    cancelled: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())


class ChallengeMember(Base):
    __tablename__ = "challenge_members"
    __table_args__ = (Index("ix_challenge_member_recent", "player_id", "joined_at"),)
    challenge_id: Mapped[str] = mapped_column(ForeignKey("challenges.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    joined_at: Mapped[int] = mapped_column(Integer, default=now)
    run_id: Mapped[str | None] = mapped_column(ForeignKey("runs.id"), nullable=True)
    time_ticks: Mapped[int | None] = mapped_column(Integer, nullable=True)


class ChallengeTicket(Base):
    __tablename__ = "challenge_tickets"
    ticket_id: Mapped[str] = mapped_column(ForeignKey("run_tickets.id"), primary_key=True)
    challenge_id: Mapped[str] = mapped_column(ForeignKey("challenges.id"), index=True)
    outcome: Mapped[dict | None] = mapped_column(JSON, nullable=True)
