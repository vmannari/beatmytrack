"""Persistent, operator-created development profiles; never competitive identities."""

from sqlalchemy import JSON, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .track_models import now


class TestDriverProfile(Base):
    __tablename__ = "test_driver_profiles"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    fleet: Mapped[str] = mapped_column(String(64), index=True)
    ordinal: Mapped[int] = mapped_column(Integer)
    subject: Mapped[str] = mapped_column(String(255), unique=True)
    traits: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
