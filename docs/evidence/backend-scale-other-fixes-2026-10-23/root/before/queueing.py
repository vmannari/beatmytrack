"""Transactional capacity slots without a globally serialized counter."""
import time

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .track_models import QueueCapacity, QueueLimit, QueuePlayer, QueueReservation


def check_capacity(session, player_id: str, capacity: int) -> None:
    pending = session.scalar(select(QueueCapacity.pending))
    owner = session.get(QueuePlayer, player_id)
    if pending >= capacity or (owner is not None and owner.pending >= 8):
        raise HTTPException(429, "Verification queue is full; retry this saved attempt later")


def admit(session, player_id: str, capacity: int) -> None:
    """Serialize only this owner. Job triggers atomically acquire a free slot.

    Limits share a read lock, which does not serialize admissions. An exclusive
    configuration lock is needed only when changing the configured capacity.
    A shrink cannot strand an occupied slot outside the new allowed range.
    """
    configured = session.scalar(select(QueueLimit.capacity).where(QueueLimit.id == 1))
    if configured != capacity:
        limit = session.scalar(select(QueueLimit).where(QueueLimit.id == 1)
            .with_for_update(skip_locked=True).execution_options(populate_existing=True))
        if limit is None:
            raise HTTPException(503, "QUEUE_CAPACITY_CONFIGURATION_BUSY")
        highest = session.scalar(select(func.max(QueueReservation.slot)))
        if highest is not None and highest >= capacity:
            raise HTTPException(503, "QUEUE_CAPACITY_CHANGE_REQUIRES_DRAIN")
        limit.capacity = capacity
        session.flush()
    else:
        # Recheck after waiting for any in-progress configuration change.
        configured = session.scalar(select(QueueLimit.capacity).where(QueueLimit.id == 1)
            .with_for_update(read=True))
        if configured != capacity:
            raise HTTPException(503, "QUEUE_CAPACITY_CONFIGURATION_CHANGED")
    insert = sqlite_insert if session.bind.dialect.name == "sqlite" else pg_insert
    session.execute(insert(QueuePlayer).values(player_id=player_id, last_claim_at=0, pending=0)
        .on_conflict_do_nothing(index_elements=[QueuePlayer.player_id]))
    owner = session.scalar(select(QueuePlayer).where(QueuePlayer.player_id == player_id)
        .with_for_update().execution_options(populate_existing=True))
    if session.scalar(select(QueueCapacity.pending)) >= capacity:
        raise HTTPException(429, "Verification capacity reached; retry this saved attempt later")
    if owner.pending >= 8:
        raise HTTPException(429, "Verification queue is full for this player; retry after a pending result completes")


def capacity_error(error) -> bool:
    """Recognize only the database's fixed, non-sensitive admission failure."""
    original = getattr(error, "orig", None)
    diagnostic = getattr(original, "diag", None)
    if diagnostic is not None:
        return (getattr(original, "sqlstate", None) == "P0001"
                and diagnostic.message_primary == "verification_capacity_reached")
    return original is not None and str(original) == "verification_capacity_reached"


def record_claim(session, queue, player_id: str) -> None:
    owner = session.get(QueuePlayer, player_id)
    owner.last_claim_at = max(owner.last_claim_at + 1, time.time_ns() // 1000)
