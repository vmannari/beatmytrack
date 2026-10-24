"""Invitation-scoped competitions; timing is written only by verification."""
from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    ForeignKey,
    ForeignKeyConstraint,
    Index,
    Integer,
    String,
    false,
)
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import new_id, now


class Challenge(Base):
    __tablename__ = "challenges"
    __table_args__ = (Index("ix_challenge_creator_recent", "creator_id", "created_at"),
                      Index("ix_challenge_discover", "visibility", "cancelled", "ends_at", "id"),
                      CheckConstraint("member_count >= 1 AND member_count <= 20"))
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    code: Mapped[str] = mapped_column(String(16), unique=True)
    creator_id: Mapped[str] = mapped_column(ForeignKey("players.id"))
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"))
    mode: Mapped[str] = mapped_column(String(8))
    visibility: Mapped[str] = mapped_column(String(8), default="private", server_default="private")
    target_run_id: Mapped[str | None] = mapped_column(ForeignKey("runs.id"), nullable=True)
    target_ticks: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    ends_at: Mapped[int] = mapped_column(Integer)
    member_count: Mapped[int] = mapped_column(Integer, default=1)
    attempt_limit: Mapped[int | None] = mapped_column(Integer, nullable=True)
    cancelled: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())


class ChallengeMember(Base):
    __tablename__ = "challenge_members"
    __table_args__ = (Index("ix_challenge_member_recent", "player_id", "joined_at"),)
    challenge_id: Mapped[str] = mapped_column(ForeignKey("challenges.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    joined_at: Mapped[int] = mapped_column(Integer, default=now)
    attempts_used: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    run_id: Mapped[str | None] = mapped_column(ForeignKey("runs.id"), nullable=True)
    time_ticks: Mapped[int | None] = mapped_column(Integer, nullable=True)


class ChallengeTicket(Base):
    __tablename__ = "challenge_tickets"
    ticket_id: Mapped[str] = mapped_column(ForeignKey("run_tickets.id"), primary_key=True)
    challenge_id: Mapped[str] = mapped_column(ForeignKey("challenges.id"), index=True)
    outcome: Mapped[dict | None] = mapped_column(JSON, nullable=True)


class ChallengeStage(Base):
    __tablename__ = "challenge_stages"
    __table_args__ = (CheckConstraint("ordinal >= 0 AND ordinal < 3"),)
    challenge_id: Mapped[str] = mapped_column(ForeignKey("challenges.id"), primary_key=True)
    ordinal: Mapped[int] = mapped_column(Integer, primary_key=True)
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"))


class ChallengeStageMember(Base):
    __tablename__ = "challenge_stage_members"
    __table_args__ = (
        ForeignKeyConstraint(["challenge_id", "ordinal"], ["challenge_stages.challenge_id", "challenge_stages.ordinal"]),
        ForeignKeyConstraint(["challenge_id", "player_id"], ["challenge_members.challenge_id", "challenge_members.player_id"]),
        CheckConstraint("attempts_used >= 0 AND attempts_used <= 3"),
        Index("ix_challenge_stage_member_run", "run_id"),
    )
    challenge_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    ordinal: Mapped[int] = mapped_column(Integer, primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    attempts_used: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    run_id: Mapped[str | None] = mapped_column(ForeignKey("runs.id"), nullable=True)
    time_ticks: Mapped[int | None] = mapped_column(Integer, nullable=True)


class ChallengeStageTicket(Base):
    __tablename__ = "challenge_stage_tickets"
    ticket_id: Mapped[str] = mapped_column(ForeignKey("challenge_tickets.ticket_id"), primary_key=True)
    ordinal: Mapped[int] = mapped_column(Integer)
