"""Bounded private news, mutual friends and explicitly requested daily work."""
from sqlalchemy import JSON, Boolean, ForeignKey, Index, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import new_id, now


class Friendship(Base):
    __tablename__ = "news_friends"
    __table_args__ = (Index("ix_news_friends_high", "high_id", "low_id"),)
    low_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    high_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    requested_by: Mapped[str] = mapped_column(String(36))
    accepted: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class NewsItem(Base):
    __tablename__ = "news_items"
    __table_args__ = (UniqueConstraint("player_id", "event_key"),
                     Index("ix_news_feed", "player_id", "created_at", "id"),
                     Index("ix_news_expiry", "created_at", "id"))
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    # Projection IDs have no implicit player FK lock. The writer explicitly
    # validates/fences recipients with a shared key lock before publication.
    player_id: Mapped[str] = mapped_column(String(36))
    event_key: Mapped[str] = mapped_column(String(64))
    kind: Mapped[str] = mapped_column(String(24))
    version_id: Mapped[str] = mapped_column(ForeignKey("track_versions.id"))
    board_id: Mapped[str | None] = mapped_column(ForeignKey("boards.id"), nullable=True)
    actor_id: Mapped[str | None] = mapped_column(String(36), nullable=True, index=True)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    details: Mapped[dict] = mapped_column(JSON, default=dict)


class NewsPublication(Base):
    """One shared first-publication fact, never a row per friend."""
    __tablename__ = "news_publications"
    __table_args__ = (Index("ix_news_publications_owner", "owner_id", "published_at", "version_id"),
                     Index("ix_news_publications_expiry", "published_at", "track_id"))
    track_id: Mapped[str] = mapped_column(ForeignKey("tracks.id"), primary_key=True)
    version_id: Mapped[str] = mapped_column(ForeignKey("track_versions.id"))
    owner_id: Mapped[str] = mapped_column(ForeignKey("players.id"))
    published_at: Mapped[int] = mapped_column(Integer)


class NewsDemand(Base):
    __tablename__ = "news_demand"
    __table_args__ = (Index("ix_news_demand_active", "pending", "requested_until", "player_id"),)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    requested_day: Mapped[int] = mapped_column(Integer, default=-1)
    completed_day: Mapped[int] = mapped_column(Integer, default=-1)
    requested_until: Mapped[int] = mapped_column(Integer, default=0)
    pending: Mapped[bool] = mapped_column(Boolean, default=False)
    cursor: Mapped[str] = mapped_column(String(64), default="")


class NewsWatch(Base):
    __tablename__ = "news_watches"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), primary_key=True)
    revision: Mapped[int] = mapped_column(Integer, default=-1)
    friend_key: Mapped[str] = mapped_column(String(64), default="")
    race_ticks: Mapped[int | None] = mapped_column(Integer, nullable=True)
    lap_ticks: Mapped[int | None] = mapped_column(Integer, nullable=True)
    race_band: Mapped[int | None] = mapped_column(Integer, nullable=True)
    lap_band: Mapped[int | None] = mapped_column(Integer, nullable=True)
    friends: Mapped[dict] = mapped_column(JSON, default=dict)


class NewsBands(Base):
    __tablename__ = "news_bands"
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), primary_key=True)
    checked_day: Mapped[int] = mapped_column(Integer)
    revision: Mapped[int] = mapped_column(Integer)
    race: Mapped[list] = mapped_column(JSON)
    lap: Mapped[list] = mapped_column(JSON)


class TrackReach(Base):
    __tablename__ = "news_track_reach"
    track_id: Mapped[str] = mapped_column(ForeignKey("tracks.id"), primary_key=True)
    racers: Mapped[int] = mapped_column(Integer, default=0)
    milestone: Mapped[int] = mapped_column(Integer, default=0)


class TrackRacer(Base):
    __tablename__ = "news_track_racers"
    track_id: Mapped[str] = mapped_column(ForeignKey("tracks.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True, index=True)
