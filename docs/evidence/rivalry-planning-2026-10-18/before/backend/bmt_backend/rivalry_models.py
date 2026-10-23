"""Pinned weekly fields; results are written only by canonical verification."""
from sqlalchemy import JSON, Boolean, ForeignKey, Index, Integer, String, UniqueConstraint, false
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import new_id, now


class RivalryGroup(Base):
    __tablename__ = "rivalry_groups"
    __table_args__ = (Index("ix_rivalry_matching", "week_start", "contract_key", "skill_band"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    week_start: Mapped[int] = mapped_column(Integer)
    ends_at: Mapped[int] = mapped_column(Integer)
    vehicle_id: Mapped[str] = mapped_column(String(80))
    contract_key: Mapped[str] = mapped_column(String(64))
    skill_band: Mapped[int] = mapped_column(Integer)
    test_population: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false(), nullable=False)
    member_count: Mapped[int] = mapped_column(Integer, default=0)
    tracks: Mapped[list] = mapped_column(JSON)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    archived: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())


class RivalryMember(Base):
    __tablename__ = "rivalry_members"
    __table_args__ = (UniqueConstraint("week_start", "player_id", "contract_key"),)
    group_id: Mapped[str] = mapped_column(ForeignKey("rivalry_groups.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    week_start: Mapped[int] = mapped_column(Integer)
    contract_key: Mapped[str] = mapped_column(String(64))
    skill: Mapped[int | None] = mapped_column(Integer, nullable=True)
    acknowledged: Mapped[bool] = mapped_column(Boolean, default=False)
    joined_at: Mapped[int] = mapped_column(Integer, default=now)


class RivalryBest(Base):
    __tablename__ = "rivalry_bests"
    group_id: Mapped[str] = mapped_column(ForeignKey("rivalry_groups.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    slot: Mapped[int] = mapped_column(Integer, primary_key=True)
    run_id: Mapped[str] = mapped_column(ForeignKey("runs.id"), unique=True)
    time_ticks: Mapped[int] = mapped_column(Integer)
    achieved_at: Mapped[int] = mapped_column(Integer, default=now)


class RivalryTicket(Base):
    __tablename__ = "rivalry_tickets"
    ticket_id: Mapped[str] = mapped_column(ForeignKey("run_tickets.id"), primary_key=True)
    group_id: Mapped[str] = mapped_column(ForeignKey("rivalry_groups.id"), index=True)
    slot: Mapped[int] = mapped_column(Integer)
    outcome: Mapped[dict | None] = mapped_column(JSON, nullable=True)


class RivalryArchivedBest(Base):
    __tablename__ = "rivalry_archived_bests"
    group_id: Mapped[str] = mapped_column(ForeignKey("rivalry_groups.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    slot: Mapped[int] = mapped_column(Integer, primary_key=True)
    time_ticks: Mapped[int] = mapped_column(Integer)
    achieved_at: Mapped[int] = mapped_column(Integer)
