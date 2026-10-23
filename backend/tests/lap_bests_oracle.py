"""Historical aggregate parity oracle; excluded from the backend package."""
from sqlalchemy import func, or_, select

from bmt_backend.identity_models import Player
from bmt_backend.track_models import Board, OperationState, PersonalBest, Run


def legacy_best_lap_times(board_id, session, *, test_population=False):
    """Offline parity oracle only; never called by requests or the worker."""
    laps = [Run.lap_ticks[index].as_integer() for index in range(1, 5)]
    shortest = func.least(*laps) if session.bind.dialect.name == "postgresql" else func.min(*laps)
    statement = select(Run.player_id, func.min(shortest).label("time_ticks")).join(
        Player, Player.id == Run.player_id).join(PersonalBest,
        (PersonalBest.board_id == Run.board_id) & (PersonalBest.player_id == Run.player_id)).where(
        Run.board_id == board_id, Run.status == "verified", Player.disabled.is_(False),
        *(lap > 0 for lap in laps))
    if not test_population:
        statement = statement.where(Player.is_test_driver.is_(False))
    else:
        # Retained audit runs from an owner-requested test-record reset must not
        # restore retired lap records. Real players are never part of that reset.
        board = session.get(Board, board_id)
        if board:
            resets = session.scalars(select(OperationState).where(
                OperationState.id.startswith("test-pop-batch:"),
                OperationState.details["vehicle_id"].as_string() == board.vehicle_id)).all()
            cutoff = max((row.details.get("created_at", 0) for row in resets
                          if row.details.get("request", {}).get("clear_test_records")
                          and any(entry.get("version_id") == board.version_id
                                  for entry in row.details.get("tracks", []))), default=0)
            if cutoff:
                statement = statement.where(or_(Player.is_test_driver.is_(False), Run.created_at >= cutoff))
    return statement.group_by(Run.player_id).subquery()

