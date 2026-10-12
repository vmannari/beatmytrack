"""Prepared diagnostic counters: no player IDs, trace text or raw trajectories."""
from sqlalchemy import JSON, BigInteger, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class QualityFact(Base):
    __tablename__ = "quality_facts"
    day: Mapped[int] = mapped_column(Integer, primary_key=True)
    kind: Mapped[str] = mapped_column(String(24), primary_key=True)
    dimension: Mapped[str] = mapped_column(String(64), primary_key=True)
    context: Mapped[dict] = mapped_column(JSON)
    reports: Mapped[int] = mapped_column(BigInteger, default=0)
    samples: Mapped[int] = mapped_column(BigInteger, default=0)
    slow: Mapped[int] = mapped_column(BigInteger, default=0)
    b0: Mapped[int] = mapped_column(BigInteger, default=0)
    b1: Mapped[int] = mapped_column(BigInteger, default=0)
    b2: Mapped[int] = mapped_column(BigInteger, default=0)
    b3: Mapped[int] = mapped_column(BigInteger, default=0)
    b4: Mapped[int] = mapped_column(BigInteger, default=0)
    b5: Mapped[int] = mapped_column(BigInteger, default=0)
    b6: Mapped[int] = mapped_column(BigInteger, default=0)
    b7: Mapped[int] = mapped_column(BigInteger, default=0)

