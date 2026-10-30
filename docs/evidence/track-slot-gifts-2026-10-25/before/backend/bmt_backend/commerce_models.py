"""Permanent entitlement and purchase ledgers; simulated balances stay separate."""
from sqlalchemy import BigInteger, Boolean, CheckConstraint, ForeignKey, Index, Integer, String, false
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .identity_models import now


class Entitlements(Base):
    __tablename__ = "entitlements"
    __table_args__ = (CheckConstraint("slots >= 0 AND simulated_slots >= 0"),)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    slots: Mapped[int] = mapped_column(Integer, default=1)
    simulated_slots: Mapped[int] = mapped_column(Integer, default=0)
    ad_free_until: Mapped[int] = mapped_column(BigInteger, default=0)
    simulated_ad_free_until: Mapped[int] = mapped_column(BigInteger, default=0)
    forever: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())
    simulated_forever: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false())


class Purchase(Base):
    __tablename__ = "purchases"
    __table_args__ = (
        Index("ix_purchase_player_created", "player_id", "created_at", "id"),
        Index("ix_purchase_player_state", "player_id", "provider", "state", "created_at", "id"),
    )
    # Namespaced provider token digest; no raw store credentials or receipt tokens.
    id: Mapped[str] = mapped_column(String(96), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"))
    provider: Mapped[str] = mapped_column(String(24))
    product_id: Mapped[str] = mapped_column(String(40))
    state: Mapped[str] = mapped_column(String(16))
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    fulfilled_at: Mapped[int | None] = mapped_column(Integer, nullable=True)


Index("ix_purchase_history", Purchase.created_at.desc(), Purchase.id)


class PublicationSlot(Base):
    __tablename__ = "publication_slots"
    version_id: Mapped[str] = mapped_column(ForeignKey("track_versions.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), index=True)
    source: Mapped[str] = mapped_column(String(16))
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class ProductControl(Base):
    __tablename__ = "product_controls"
    __table_args__ = (CheckConstraint("revision >= 0"),)
    id: Mapped[str] = mapped_column(String(40), primary_key=True)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    revision: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    updated_at: Mapped[int] = mapped_column(Integer, default=now)
