"""Cooperatively yield development generation when a player submits a race."""
import time

from sqlalchemy import and_, or_, select

from .identity_models import Player
from .job_contracts import pinned_filter
from .track_models import Board, Run, now


class BackgroundYielded(RuntimeError):
    """Keep the unfinished artificial attempt for the next idle period."""


class BackgroundControl:
    def __init__(self, app):
        self.app = app
        self.next_check = 0.0
        self.manifest = app.state.verifier.manifest()

    def is_set(self):
        control = getattr(self.app.state, "worker_control", None)
        if control and control.abort.is_set():
            return True
        current = time.monotonic()
        if current < self.next_check:
            return False
        self.next_check = current + 0.25
        with self.app.state.session_factory() as session:
            pending = session.scalar(select(Run.id).join(Board).join(Player, Player.id == Run.player_id)
                .where(Player.is_test_driver.is_(False), pinned_filter(Board.manifest, self.manifest),
                       or_(and_(Run.status == "queued", Run.lease_until <= now()),
                           and_(Run.status == "verifying", Run.lease_until <= now())))
                .limit(1))
        if pending is not None:
            raise BackgroundYielded("Player race is ready for verification")
        return False
