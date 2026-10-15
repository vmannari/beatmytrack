"""Persistent content, competition and durable verification queue boundaries."""

from __future__ import annotations

import hashlib
import json
import re
import time
import uuid

from fastapi import HTTPException
from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
    CheckConstraint,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Mapped, Session, mapped_column

from .db import Base


def new_id() -> str:
    return str(uuid.uuid4())


def now() -> int:
    return int(time.time())


def digest(value: object) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
    ).hexdigest()


class Track(Base):
    __tablename__ = "tracks"
    __table_args__ = (UniqueConstraint("owner_id", "authoring_id"),)
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    owner_id: Mapped[str] = mapped_column(ForeignKey("players.id"), index=True)
    authoring_id: Mapped[str | None] = mapped_column(String(80), nullable=True)
    hidden: Mapped[bool] = mapped_column(Boolean, default=False)
    archived: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    official: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class TrackVersion(Base):
    __tablename__ = "track_versions"
    __table_args__ = (
        UniqueConstraint("track_id", "number"),
        UniqueConstraint("track_id", "revision_key"),
        Index("ix_track_discovery", "state", "published_at", "id"),
    )
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    track_id: Mapped[str] = mapped_column(ForeignKey("tracks.id"), index=True)
    number: Mapped[int] = mapped_column(Integer)
    name: Mapped[str] = mapped_column(String(80))
    content_hash: Mapped[str] = mapped_column(String(64))
    redacted_track_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    revision_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    manifest: Mapped[dict] = mapped_column(JSON)
    discovery: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    state: Mapped[str] = mapped_column(String(16), default="draft")
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    published_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    creator_test_run_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    rating_sum: Mapped[int] = mapped_column(Integer, default=0)
    rating_count: Mapped[int] = mapped_column(Integer, default=0)
    verified_finishers: Mapped[int] = mapped_column(Integer, default=0, server_default="0")


class TrackValidation(Base):
    __tablename__ = "track_validations"
    __table_args__ = (Index("ix_validation_claim", "status", "lease_until", "created_at"),)
    version_id: Mapped[str] = mapped_column(ForeignKey("track_versions.id"), primary_key=True)
    status: Mapped[str] = mapped_column(String(16), default="queued")
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    lease_until: Mapped[int] = mapped_column(Integer, default=0)
    lease_token: Mapped[str | None] = mapped_column(String(36), nullable=True)
    failure_code: Mapped[str | None] = mapped_column(String(64), nullable=True)
    detail: Mapped[str | None] = mapped_column(String(500), nullable=True)
    legacy_workflow_snapshot: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class Board(Base):
    __tablename__ = "boards"
    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    version_id: Mapped[str] = mapped_column(ForeignKey("track_versions.id"), index=True)
    vehicle_id: Mapped[str] = mapped_column(String(80))
    manifest: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    stats_revision: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    lap_revision: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    public_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    all_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")


class HistogramSnapshot(Base):
    """Durable comparison field, rebuilt by the idle worker, never a GET."""
    __tablename__ = "histogram_snapshots"
    __table_args__ = (Index("ix_histogram_snapshots_dirty_due", "dirty", "next_refresh_at", "lease_until"),)
    version_id: Mapped[str] = mapped_column(ForeignKey("track_versions.id"), primary_key=True)
    vehicle_id: Mapped[str] = mapped_column(String(80), primary_key=True)
    include_artificial: Mapped[bool] = mapped_column(Boolean, primary_key=True)
    generation: Mapped[str] = mapped_column(String(36), default="", server_default="")
    source_revision: Mapped[int] = mapped_column(Integer, default=-1, server_default="-1")
    source_fingerprint: Mapped[str] = mapped_column(String(64), default="", server_default="")
    population: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    updated_at: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    next_refresh_at: Mapped[int] = mapped_column(Integer, default=0, server_default="0", index=True)
    lease_until: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    lease_token: Mapped[str | None] = mapped_column(String(36), nullable=True)
    invalidated: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    dirty: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    payload: Mapped[dict] = mapped_column(JSON, default=dict)


class RunTicket(Base):
    __tablename__ = "run_tickets"
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), index=True)
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"))
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    expires_at: Mapped[int] = mapped_column(Integer)


class Run(Base):
    __tablename__ = "runs"
    __table_args__ = (Index("ix_run_claim", "status", "lease_until", "created_at"),
                      Index("ix_run_created_at", "created_at"),
                      Index("ix_run_board_player_id", "board_id", "player_id", "id"),
                      Index("ix_run_board_id", "board_id", "id"))
    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    ticket_id: Mapped[str] = mapped_column(ForeignKey("run_tickets.id"), unique=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), index=True)
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), index=True)
    replay_hash: Mapped[str] = mapped_column(String(64))
    ghost_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    status: Mapped[str] = mapped_column(String(16), default="queued")
    created_at: Mapped[int] = mapped_column(Integer, default=now)
    finished_at: Mapped[int | None] = mapped_column(Integer, nullable=True)
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    lease_until: Mapped[int] = mapped_column(Integer, default=0)
    lease_token: Mapped[str | None] = mapped_column(String(36), nullable=True)
    time_ticks: Mapped[int | None] = mapped_column(Integer, nullable=True)
    lap_ticks: Mapped[list | None] = mapped_column(JSON, nullable=True)
    failure_code: Mapped[str | None] = mapped_column(String(64), nullable=True)


class PersonalBest(Base):
    __tablename__ = "personal_bests"
    __table_args__ = (Index("ix_pb_rank", "board_id", "time_ticks", "player_id"),
                      Index("ix_pb_player_recent", "player_id", "achieved_at", "board_id"))
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    run_id: Mapped[str] = mapped_column(ForeignKey("runs.id"), unique=True)
    time_ticks: Mapped[int] = mapped_column(Integer)
    achieved_at: Mapped[int] = mapped_column(Integer, default=now)


class LapPersonalBest(Base):
    """Independent accepted flying-lap minimum; its source survives retention."""
    __tablename__ = "lap_personal_bests"
    __table_args__ = (CheckConstraint("time_ticks > 0"), CheckConstraint("lap_index BETWEEN 1 AND 4"),)
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    run_id: Mapped[str] = mapped_column(ForeignKey("runs.id"), index=True)
    time_ticks: Mapped[int] = mapped_column(Integer)
    lap_index: Mapped[int] = mapped_column(Integer)
    achieved_at: Mapped[int] = mapped_column(Integer)
    source_created_at: Mapped[int] = mapped_column(Integer)


class LapBestState(Base):
    """Bounded backfill cursor and irreversible artificial-record reset fence."""
    __tablename__ = "lap_best_state"
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), primary_key=True)
    cutoff: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    epoch: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    cursor: Mapped[str] = mapped_column(String(36), default="", server_default="")
    complete: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    invalid_records: Mapped[int] = mapped_column(Integer, default=0, server_default="0")


class Rating(Base):
    __tablename__ = "ratings"
    __table_args__ = (CheckConstraint("score >= 1 AND score <= 5"),)
    version_id: Mapped[str] = mapped_column(ForeignKey("track_versions.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    score: Mapped[int] = mapped_column(Integer)
    updated_at: Mapped[int] = mapped_column(Integer, default=now)


class IdempotencyRecord(Base):
    __tablename__ = "domain_idempotency"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    scope: Mapped[str] = mapped_column(String(128), primary_key=True)
    key: Mapped[str] = mapped_column(String(128), primary_key=True)
    request_hash: Mapped[str] = mapped_column(String(64))
    response: Mapped[dict] = mapped_column(JSON)
    created_at: Mapped[int] = mapped_column(Integer, default=now)


class QueuePlayer(Base):
    __tablename__ = "queue_players"
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True)
    last_claim_at: Mapped[int] = mapped_column(BigInteger, default=0, index=True)
    pending: Mapped[int] = mapped_column(Integer, default=0, server_default="0")


class QueueCapacity(Base):
    __tablename__ = "queue_capacity"
    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    pending: Mapped[int] = mapped_column(Integer, default=0)


class BoardTimeCount(Base):
    """Exact tick frequencies; size is bounded by the replay tick limit, not players."""
    __tablename__ = "board_time_counts"
    board_id: Mapped[str] = mapped_column(ForeignKey("boards.id"), primary_key=True)
    time_ticks: Mapped[int] = mapped_column(Integer, primary_key=True)
    public_count: Mapped[int] = mapped_column(Integer, default=0)
    all_count: Mapped[int] = mapped_column(Integer, default=0)


class VersionFinisher(Base):
    __tablename__ = "version_finishers"
    version_id: Mapped[str] = mapped_column(ForeignKey("track_versions.id"), primary_key=True)
    player_id: Mapped[str] = mapped_column(ForeignKey("players.id"), primary_key=True, index=True)
    board_count: Mapped[int] = mapped_column(Integer)


class OperationState(Base):
    __tablename__ = "operation_state"
    id: Mapped[str] = mapped_column(String(80), primary_key=True)
    updated_at: Mapped[int] = mapped_column(Integer, default=now, index=True)
    details: Mapped[dict] = mapped_column(JSON, default=dict)


def replay_response(session: Session, player_id: str, scope: str, key: str, body: object) -> dict | None:
    if not 8 <= len(key) <= 128 or any(ord(c) < 33 or ord(c) > 126 for c in key):
        raise HTTPException(
            422, "Idempotency-Key must contain 8..128 printable ASCII characters without spaces"
        )
    if key.startswith("v2."):
        match = re.fullmatch(r"v2\.([0-9]{10})\.[0-9a-f]{48}", key)
        if not match:
            raise HTTPException(422, "INVALID_IDEMPOTENCY_KEY")
        issued = int(match[1])
        if issued < now() - 90*86400:
            raise HTTPException(410, "Idempotency key expired; this request will not be repeated")
        if issued > now() + 86400:
            raise HTTPException(422, "IDEMPOTENCY_CLOCK_AHEAD")
    record = session.get(IdempotencyRecord, (player_id, scope, key))
    if record is None:
        return None
    if record.request_hash != digest(body):
        raise HTTPException(409, "Idempotency-Key already used for different content")
    if record.response.get("retired"):
        raise HTTPException(410, "Attempt history expired; this request will not be repeated")
    return record.response


def commit_response(
    session: Session, player_id: str, scope: str, key: str, body: object, response: dict
) -> dict:
    session.add(
        IdempotencyRecord(
            player_id=player_id, scope=scope, key=key, request_hash=digest(body), response=response
        )
    )
    try:
        session.commit()
    except IntegrityError:
        session.rollback()
        existing = replay_response(session, player_id, scope, key, body)
        if existing is not None:
            return existing
        raise HTTPException(
            409, "Concurrent write; retry this request with the same Idempotency-Key"
        ) from None
    return response
