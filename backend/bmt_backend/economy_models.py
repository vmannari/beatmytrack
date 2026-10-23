"""Earned coins and permanent cosmetic ownership, separate from paid commerce/resumes."""
from sqlalchemy import JSON, BigInteger, CheckConstraint, ForeignKey, Integer, String
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
