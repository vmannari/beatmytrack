"""Immutable policy snapshots and bounded control metadata, separate from race rules."""
from sqlalchemy import JSON, BigInteger, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import now


class GameConfigControl(Base):
    __tablename__ = "game_config_control"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    revision: Mapped[int] = mapped_column(Integer, default=0)
    active_generation: Mapped[int] = mapped_column(Integer, default=0)
    emergency: Mapped[dict] = mapped_column(JSON, default=dict)


class GameConfigDraft(Base):
    __tablename__ = "game_config_drafts"
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    revision: Mapped[int] = mapped_column(Integer, default=0)
    base_generation: Mapped[int] = mapped_column(Integer)
    policy: Mapped[dict] = mapped_column(JSON)
    audiences: Mapped[list] = mapped_column(JSON)
    updated_at: Mapped[int] = mapped_column(BigInteger, default=now)


class GameConfigRelease(Base):
    __tablename__ = "game_config_releases"
    generation: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=False)
    name: Mapped[str] = mapped_column(String(100))
    policy: Mapped[dict] = mapped_column(JSON)
    audiences: Mapped[list] = mapped_column(JSON)
    fallback: Mapped[dict] = mapped_column(JSON)
    rollout: Mapped[int] = mapped_column(Integer)
    internal_players: Mapped[list] = mapped_column(JSON, default=list)
    salt: Mapped[str] = mapped_column(String(64))
    state: Mapped[str] = mapped_column(String(24))
    base_generation: Mapped[int] = mapped_column(Integer)
    scheduled_at: Mapped[int] = mapped_column(BigInteger, index=True)
    created_at: Mapped[int] = mapped_column(BigInteger, default=now)
    actor: Mapped[str] = mapped_column(String(80))


class GameConfigDelivery(Base):
    __tablename__ = "game_config_deliveries"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    generation: Mapped[int] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(16))
    platform: Mapped[str] = mapped_column(String(16))
    build_id: Mapped[str] = mapped_column(String(80))
    observed_at: Mapped[int] = mapped_column(BigInteger, index=True)
    applied_groups: Mapped[dict] = mapped_column(JSON, default=dict)
