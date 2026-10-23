"""Account-scoped safety preferences and explicit, versioned publication consent."""
from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import now


class CommunityAcceptance(Base):
    __tablename__ = "community_acceptances"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    version: Mapped[str] = mapped_column(String(64), primary_key=True)
    accepted_at: Mapped[int] = mapped_column(Integer, default=now)


class PlayerBlock(Base):
    __tablename__ = "player_blocks"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    blocked_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True, index=True)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
