"""Short, constant-cost admission and independent owner fairness."""
import time

from fastapi import HTTPException
from sqlalchemy import select

from .track_models import QueueCapacity, QueuePlayer


def check_capacity(session, player_id: str, capacity: int) -> None:
    queue = session.get(QueueCapacity, 1)
    owner = session.get(QueuePlayer, player_id)
    if queue.pending >= capacity or (owner is not None and owner.pending >= 8):
        raise HTTPException(429, "Verification queue is full; retry this saved attempt later")


def admit(session, player_id: str, capacity: int) -> None:
    """Counters are transactional; blob publication must precede this short lock."""
    queue = session.scalar(select(QueueCapacity).where(QueueCapacity.id == 1).with_for_update().execution_options(populate_existing=True))
    if queue.pending >= capacity:
        raise HTTPException(429, "Verification capacity reached; retry this saved attempt later")
    owner = session.get(QueuePlayer, player_id)
    if owner is not None and owner.pending >= 8:
        raise HTTPException(429, "Verification queue is full for this player; retry after a pending result completes")


def record_claim(session, queue, player_id: str) -> None:
    owner = session.get(QueuePlayer, player_id)
    owner.last_claim_at = max(owner.last_claim_at + 1, time.time_ns() // 1000)
