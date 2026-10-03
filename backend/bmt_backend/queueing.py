"""Shared admission and owner fairness for expensive canonical jobs."""
from fastapi import HTTPException
from sqlalchemy import func, select

from .track_models import OperationState, QueuePlayer, Run, Track, TrackValidation, TrackVersion


def admit(session, player_id: str, capacity: int) -> None:
    """Hold the shared row lock until the caller commits its new/retried job."""
    session.scalar(select(OperationState).where(OperationState.id == "queue").with_for_update())
    runs = select(func.count()).select_from(Run).where(Run.status.in_(("queued", "verifying")))
    validations = (select(func.count()).select_from(TrackValidation).join(TrackVersion)
                   .join(Track).where(TrackValidation.status.in_(("queued", "validating"))))
    if session.scalar(runs) + session.scalar(validations) >= capacity:
        raise HTTPException(429, "Verification capacity reached; retry this saved attempt later")
    if session.scalar(runs.where(Run.player_id == player_id)) + session.scalar(validations.where(Track.owner_id == player_id)) >= 8:
        raise HTTPException(429, "Verification queue is full for this player; retry after a pending result completes")
    if session.get(QueuePlayer, player_id) is None:
        session.add(QueuePlayer(player_id=player_id, last_claim_at=0))


def record_claim(session, queue, player_id: str) -> None:
    claim_number = int(queue.details.get("claims", 0)) + 1
    queue.details = {"claims": claim_number}
    owner = session.get(QueuePlayer, player_id)
    if owner is None:
        session.add(QueuePlayer(player_id=player_id, last_claim_at=claim_number))
    else:
        owner.last_claim_at = claim_number
