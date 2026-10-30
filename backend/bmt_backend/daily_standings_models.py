"""One verified daily minimum per player and immutable vehicle board."""
from sqlalchemy import BigInteger, CheckConstraint, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class DailyBest(Base):
    __tablename__ = "track_of_day_bests"
    __table_args__ = (Index("ix_daily_best_order", "day", "board_id", "time_ticks", "player_id"),
                      CheckConstraint("time_ticks > 0 AND time_ticks <= 216000"))
    day: Mapped[int] = mapped_column(BigInteger, primary_key=True)
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id", ondelete="CASCADE"), primary_key=True)
    # Accepted evidence may be archived later; the minimum must survive that retention.
    run_id: Mapped[str] = mapped_column(String(36))
    time_ticks: Mapped[int] = mapped_column(Integer)
    achieved_at: Mapped[int] = mapped_column(BigInteger)
