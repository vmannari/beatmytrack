import time
import uuid

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
    event,
    false,
)
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base
from .usernames import username_key


def new_id() -> str:
    return str(uuid.uuid4())


def now() -> int:
    return int(time.time())


class Player(Base):
    __tablename__ = "players"
    __table_args__ = (
        CheckConstraint("needs_username OR username_key IS NOT NULL", name="ck_player_claimed_name"),
    )
    username_key: Mapped[str | None] = mapped_column(String(160), unique=True, nullable=True)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    display_name: Mapped[str] = mapped_column(String(40), default="Racer")
    needs_username: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default=false(), nullable=False
    )
    disabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_test_driver: Mapped[bool] = mapped_column(Boolean, default=False, server_default=false(), nullable=False)
    created_at: Mapped[int] = mapped_column(Integer, default=now)


@event.listens_for(Player, "before_insert")
@event.listens_for(Player, "before_update")
def set_username_key(_mapper, _connection, player):
    player.username_key = None if player.needs_username else username_key(player.display_name or "Racer")


class Identity(Base):
    __tablename__ = "identities"
    __table_args__ = (UniqueConstraint("provider", "subject", name="uq_identity_provider_subject"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), index=True)
    provider: Mapped[str] = mapped_column(String(32))
    subject: Mapped[str] = mapped_column(String(255))


class LoginChallenge(Base):
    __tablename__ = "login_challenges"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    nonce_hash: Mapped[str] = mapped_column(String(64))
    expires_at: Mapped[int] = mapped_column(Integer, index=True)
    used: Mapped[bool] = mapped_column(Boolean, default=False)


class BrowserLogin(Base):
    __tablename__ = "browser_logins"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    browser_hash: Mapped[str] = mapped_column(String(64), unique=True)
    poll_hash: Mapped[str] = mapped_column(String(64), unique=True)
    nonce: Mapped[str] = mapped_column(String(64))
    display_name: Mapped[str] = mapped_column(String(40))
    subject: Mapped[str | None] = mapped_column(String(255), nullable=True)
    expires_at: Mapped[int] = mapped_column(Integer, index=True)
    consumed: Mapped[bool] = mapped_column(Boolean, default=False)


class SessionFamily(Base):
    __tablename__ = "session_families"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), index=True)
    expires_at: Mapped[int] = mapped_column(Integer, index=True)
    revoked: Mapped[bool] = mapped_column(Boolean, default=False)


class SessionToken(Base):
    __tablename__ = "session_tokens"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    family_id: Mapped[str] = mapped_column(ForeignKey("session_families.id", ondelete="CASCADE"), index=True)
    access_hash: Mapped[str] = mapped_column(String(64), unique=True)
    refresh_hash: Mapped[str] = mapped_column(String(64), unique=True)
    access_expires_at: Mapped[int] = mapped_column(Integer)
    consumed: Mapped[bool] = mapped_column(Boolean, default=False)


class RateBucket(Base):
    __tablename__ = "rate_buckets"
    key: Mapped[str] = mapped_column(String(64), primary_key=True)
    count: Mapped[int] = mapped_column(Integer, default=1)
    expires_at: Mapped[int] = mapped_column(Integer)
    __table_args__ = (Index("ix_rate_bucket_expiry", "expires_at"),)
