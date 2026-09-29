"""Resume balances and immutable race-bound consumption receipts."""

from sqlalchemy import CheckConstraint, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import new_id, now


class ResumeWallet(Base):
    __tablename__ = "resume_wallets"
    __table_args__ = (CheckConstraint("balance >= 0"),)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    balance: Mapped[int] = mapped_column(Integer, default=0)
    free_day: Mapped[int] = mapped_column(Integer, default=-1)


class ResumeRace(Base):
    __tablename__ = "resume_races"
    __table_args__ = (CheckConstraint("used >= 0 AND used <= 3"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), index=True)
    ticket_id: Mapped[str | None] = mapped_column(ForeignKey("run_tickets.id"), unique=True)
    used: Mapped[int] = mapped_column(Integer, default=0)
    expires_at: Mapped[int] = mapped_column(Integer)


class ResumeReceipt(Base):
    __tablename__ = "resume_receipts"
    __table_args__ = (UniqueConstraint("race_id", "ordinal"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    race_id: Mapped[str] = mapped_column(ForeignKey("resume_races.id"), index=True)
    ordinal: Mapped[int] = mapped_column(Integer)
    source: Mapped[str] = mapped_column(String(16))
    input_offset: Mapped[int] = mapped_column(Integer)
    from_tick: Mapped[int] = mapped_column(Integer)
    to_tick: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class ResumeGrant(Base):
    __tablename__ = "resume_grants"
    id: Mapped[str] = mapped_column(String(160), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), index=True)
    source: Mapped[str] = mapped_column(String(16))
    quantity: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
