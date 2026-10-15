"""Durable erasure progress, credential-bound receipts and reference-aware cleanup."""
from sqlalchemy import ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base


class AccountDeletion(Base):
    __tablename__ = "account_deletions"
    __table_args__ = (Index("ix_account_deletion_due", "completed_at", "next_attempt_at"),
                     Index("ix_account_deletion_receipt", "credential_hash", "operation_hash"))
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    operation_hash: Mapped[str] = mapped_column(String(64))
    credential_hash: Mapped[str] = mapped_column(String(64))
    requested_at: Mapped[int] = mapped_column(Integer)
    journal_written_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    completed_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    stage: Mapped[int] = mapped_column(Integer, default=0)
    plan_version: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    cursor: Mapped[str] = mapped_column(String(36), default="")
    next_attempt_at: Mapped[int] = mapped_column(Integer, default=0)


class DeletionBlob(Base):
    __tablename__ = "deletion_blobs"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    digest: Mapped[str] = mapped_column(String(64), primary_key=True)
