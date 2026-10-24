"""Earned coins and permanent cosmetic ownership, separate from paid commerce/resumes."""
from sqlalchemy import JSON, BigInteger, Boolean, CheckConstraint, ForeignKey, Index, Integer, String, text
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import now


class CoinWallet(Base):
    __tablename__ = "coin_wallets"
    __table_args__ = (CheckConstraint("balance >= 0 AND balance <= 2147483647"),)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    balance: Mapped[int] = mapped_column(Integer, default=0)
    revision: Mapped[int] = mapped_column(Integer, default=0)


class CosmeticUnlock(Base):
    __tablename__ = "cosmetic_unlocks"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    item_id: Mapped[str] = mapped_column(String(100), primary_key=True)
    price: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class CoinReward(Base):
    __tablename__ = "coin_rewards"
    __table_args__ = (Index("ix_coin_reward_archive", "created_at", "run_id"),)
    # Durable operation identity survives ordinary verified-run retention.
    run_id: Mapped[str] = mapped_column(String(36), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), index=True)
    amount: Mapped[int] = mapped_column(Integer)
    rows: Mapped[list] = mapped_column(JSON)
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class CoinMilestone(Base):
    __tablename__ = "coin_milestones"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    scope: Mapped[str] = mapped_column(String(120), primary_key=True)
    value: Mapped[int] = mapped_column(Integer, default=0)


class RewardRankCount(Base):
    """Sparse exact prefix index, maintained transactionally by PB/player triggers."""
    __tablename__ = "reward_rank_counts"
    __table_args__ = (CheckConstraint("total >= 0"),
                      CheckConstraint("node > 0 AND node <= 2147483648"),
                      CheckConstraint("metric IN ('race','lap')"))
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), primary_key=True)
    metric: Mapped[str] = mapped_column(String(4), primary_key=True)
    node: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    total: Mapped[int] = mapped_column(BigInteger)


class LeaderboardRankCount(Base):
    """Disjoint ordinary/test prefixes; artificial reads combine both."""
    __tablename__ = "leaderboard_rank_counts"
    __table_args__ = (CheckConstraint("total >= 0"),)
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), primary_key=True)
    population: Mapped[str] = mapped_column(String(6), primary_key=True)
    node: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    total: Mapped[int] = mapped_column(BigInteger)


class LeaderboardTieNode(Base):
    """Compressed radix tree; singleton ties consume just one leaf."""
    __tablename__ = "leaderboard_tie_nodes"
    __table_args__ = (CheckConstraint("total > 0"),
                      Index("ix_leaderboard_tie_children", "board_id", "time_ticks", "parent", "prefix"),
                      Index("ix_leaderboard_visible_order", "board_id", "time_ticks", "prefix",
                            postgresql_where=text("leaf IS TRUE"), sqlite_where=text("leaf IS 1")))
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), primary_key=True)
    time_ticks: Mapped[int] = mapped_column(Integer, primary_key=True)
    prefix: Mapped[str] = mapped_column(String(36), primary_key=True)
    leaf: Mapped[bool] = mapped_column(Boolean, primary_key=True)
    parent: Mapped[str | None] = mapped_column(String(36), nullable=True)
    total: Mapped[int] = mapped_column(BigInteger)
