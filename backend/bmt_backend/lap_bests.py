"""Bounded, reset-fenced backfill of accepted flying-lap personal bests."""
from sqlalchemy import func, or_, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .identity_models import Player
from .track_models import Board, LapBestState, LapPersonalBest, OperationState, PersonalBest, Run


def accepted_lap(run, manifest):
    laps = run.lap_ticks
    if (run.status != "verified" or not run.time_ticks or run.time_ticks <= 0
            or manifest.get("purpose") == "creator_test" or not isinstance(laps, list) or len(laps) != 5
            or any(type(ticks) is not int or not 1 <= ticks <= 216000 for ticks in laps)):
        return None
    index = min(range(1, 5), key=lambda i: (laps[i], i))
    return {"board_id":run.board_id, "player_id":run.player_id, "run_id":run.id,
            "time_ticks":laps[index], "lap_index":index, "achieved_at":run.finished_at or run.created_at,
            "source_created_at":run.created_at}


def backfill_one(factory, *, limit=200, after_read=None):
    """One board, at most 200 attempts. Cursor and PB inserts commit together.

    A reset can proceed during the read. Its epoch/cursor is rechecked while
    holding the state row at publication; stale batches never restore records.
    New accepted runs are captured by DB triggers independently of this cursor.
    """
    if not 1 <= limit <= 200:
        raise ValueError("Lap backfill batch must contain 1..200 attempts")
    with factory() as session:
        state = session.scalar(select(LapBestState).where(LapBestState.complete.is_(False))
                               .order_by(LapBestState.board_id).limit(1))
        if state is None:
            return {"worked":False, "complete":True, "inspected":0, "invalid_records":0}
        board_id, epoch, cursor, cutoff = state.board_id, state.epoch, state.cursor, state.cutoff
        board = session.get(Board, board_id)
        rows = session.execute(select(Run, Player.is_test_driver).join(Player, Player.id == Run.player_id)
            .where(Run.board_id == board_id, Run.id > cursor).order_by(Run.id).limit(limit)).all()
        next_cursor = rows[-1][0].id if rows else cursor
    if after_read:
        after_read()
    with factory() as session:
        if session.bind.dialect.name == "sqlite":
            # SQLite has no row locks: reserve its single writer before checking
            # the epoch, so another connection cannot reset between check/insert.
            session.connection().exec_driver_sql("BEGIN IMMEDIATE")
        current = session.scalar(select(LapBestState).where(LapBestState.board_id == board_id).with_for_update())
        if current.epoch != epoch or current.cursor != cursor or current.complete:
            return {"worked":True, "complete":False, "inspected":len(rows), "fenced":True, "invalid_records":0}
        # Re-read and hold these old source facts through publication. A source
        # corrected/deleted during the initial read cannot become a stale PB.
        live = session.execute(select(Run, Player.is_test_driver).join(Player, Player.id == Run.player_id)
            .where(Run.id.in_([run.id for run,_ in rows]), Run.board_id == board_id)
            .with_for_update(read=True, of=Run)).all()
        values, invalid = [], 0
        for run, artificial in live:
            value = accepted_lap(run, board.manifest)
            if value and not (board.manifest.get("test_population") and artificial and run.created_at < cutoff):
                values.append(value)
            elif run.status == "verified" and board.manifest.get("purpose") != "creator_test" and value is None:
                invalid += 1
        insert = sqlite_insert if session.bind.dialect.name == "sqlite" else pg_insert
        # Collapse this bounded batch to one candidate per driver before writing.
        best = {}
        for value in values:
            key = value["player_id"]
            if key not in best or value["time_ticks"] < best[key]["time_ticks"]:
                best[key] = value
        for value in best.values():
            statement = insert(LapPersonalBest).values(**value)
            session.execute(statement.on_conflict_do_update(
                index_elements=[LapPersonalBest.board_id, LapPersonalBest.player_id],
                set_={name:getattr(statement.excluded, name) for name in (
                    "time_ticks","run_id","lap_index","achieved_at","source_created_at")},
                where=LapPersonalBest.time_ticks > statement.excluded.time_ticks))
        current.cursor = next_cursor
        current.invalid_records += invalid
        current.complete = len(rows) < limit
        session.commit()
    return {"worked":True, "complete":False, "board_complete":len(rows)<limit,
            "inspected":len(rows), "invalid_records":invalid}


def backfill_all_for_diagnostics(factory):
    """Explicit maintenance/tests only; never run in a GET or race acceptance."""
    batches = 0
    while backfill_one(factory)["worked"]:
        batches += 1
    return batches


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

