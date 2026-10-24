"""Bounded career projections. No per-frame events or duplicate race ledger."""
from sqlalchemy import JSON, BigInteger, Boolean, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class AchievementState(Base):
    __tablename__ = "achievement_states"
    __table_args__ = (Index("ix_achievement_rarity_pending", "rarity_pending", "player_id", "scope"),)
    # Deliberately no Player FK/key locks for creator projections, as in News.
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    scope: Mapped[str] = mapped_column(String(8), primary_key=True)
    metrics: Mapped[dict] = mapped_column(JSON, default=dict)
    unlocked: Mapped[dict] = mapped_column(JSON, default=dict)
    featured: Mapped[list] = mapped_column(JSON, default=list)
    revision: Mapped[int] = mapped_column(Integer, default=0)
    rarity_pending: Mapped[bool] = mapped_column(Boolean, default=False)
    rarity_counted: Mapped[list] = mapped_column(JSON, default=list)


class AchievementCohort(Base):
    __tablename__ = "achievement_cohort"
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)


class AchievementCount(Base):
    __tablename__ = "achievement_counts"
    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    shard: Mapped[int] = mapped_column(Integer, primary_key=True)
    value: Mapped[int] = mapped_column(BigInteger, default=0)


class AchievementFact(Base):
    __tablename__ = "achievement_facts"
    player_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    kind: Mapped[str] = mapped_column(String(16), primary_key=True)
    identity: Mapped[str] = mapped_column(String(64), primary_key=True)


class AchievementCompetition(Base):
    __tablename__ = "achievement_competitions"
    __table_args__ = (Index("ix_achievement_competition_due", "done", "due_at", "id"),)
    kind: Mapped[str] = mapped_column(String(12), primary_key=True)
    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    due_at: Mapped[int] = mapped_column(Integer)
    done: Mapped[bool] = mapped_column(Boolean, default=False)
    facts: Mapped[dict] = mapped_column(JSON, default=dict)


class AchievementRecord(Base):
    __tablename__ = "achievement_records"
    __table_args__ = (Index("ix_achievement_record_due", "due_at", "board_id"),)
    board_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    player_id: Mapped[str] = mapped_column(String(36), index=True)
    ticks: Mapped[int] = mapped_column(Integer)
    since: Mapped[int] = mapped_column(Integer)
    due_at: Mapped[int] = mapped_column(Integer)


class CreatorAchievementPartition(Base):
    """Shared intake / exclusive erasure fences; reducers use NO KEY UPDATE."""
    __tablename__ = "creator_achievement_partitions"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)


class CreatorAchievementEvent(Base):
    """Pending effects only. CoinReward is the permanent accepted-run receipt."""
    __tablename__ = "creator_achievement_events"
    __table_args__ = (
        Index("ix_creator_achievement_pending", "partition", "stamp", "id"),
        Index("ix_creator_achievement_owner", "creator_id", "stamp", "id"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True)  # accepted run
    partition: Mapped[int] = mapped_column(Integer)
    creator_id: Mapped[str] = mapped_column(String(36))  # no Player FK/key locks
    stamp: Mapped[int] = mapped_column(Integer)
    reach: Mapped[int] = mapped_column(BigInteger, default=0)
