"""Daily evidence has its own board; partial race totals never become race PBs."""
from fastapi import HTTPException
from sqlalchemy import func, select

from .daily_standings_models import DailyBest
from .discovery_models import TrackOfDay
from .discovery_projection import insert
from .identity_models import Player
from .track_models import RunTicket, digest, now


def manifest(pinned, day):
    return {**pinned, "purpose": "daily_laps", "laps": 10, "daily_day": day}


def ticket_manifest(session, version, pinned, player, test_population):
    from .daily_fixed_limits import selection_for_version
    day = now() // 86400
    chosen = session.get(TrackOfDay, day)
    selection = selection_for_version(chosen, version.id) if chosen else None
    values = selection.get("vehicles", {}).get(pinned["vehicle_id"], {}) if selection else {}
    if (player.is_test_driver or test_population or values.get("manifest") != pinned
            or not values.get("cutoffs")):
        raise HTTPException(409, "DAILY_LAP_CONTRACT_UNAVAILABLE")
    return manifest(pinned, day)


def accept(session, run):
    from .track_models import Board
    ticket = session.get(RunTicket, run.ticket_id)
    board = session.get(Board, run.board_id)
    day = board.manifest["daily_day"]
    # Upload may finish later; the signed ticket fixes the competition day.
    # Verification completion time never moves a result into another day.
    if (run.status != "verified" or not ticket or ticket.created_at // 86400 != day
            or ticket.player_id != run.player_id or ticket.board_id != run.board_id
            or not 2 <= len(run.lap_ticks) <= 10):
        return False
    values = {"day": day, "board_id": board.id, "player_id": run.player_id,
              "run_id": run.id, "time_ticks": min(run.lap_ticks[1:]), "achieved_at": run.created_at}
    statement = insert(session, DailyBest).values(**values)
    session.execute(statement.on_conflict_do_update(index_elements=["day", "board_id", "player_id"],
        set_={key: values[key] for key in ("run_id", "time_ticks", "achieved_at")},
        where=DailyBest.time_ticks > values["time_ticks"]))
    return True


def board_id(context):
    return digest({"version_id": context["version_id"], **manifest(context["manifest"], context["day"])})


def scores(context):
    return select(DailyBest.player_id, DailyBest.time_ticks).join(Player, Player.id == DailyBest.player_id).where(
        DailyBest.day == context["day"], DailyBest.board_id == board_id(context),
        Player.disabled.is_(False), Player.deleted_at.is_(None), Player.is_test_driver.is_(False))


def overlay(session, context, population, laps=None):
    """Deduplicate daily and reference PBs; reference cutoffs remain immutable."""
    from .histogram_population import HistogramPopulation
    if population.own is not None:
        own = dict(population.own)
        for identity, ticks in session.execute(scores(context)):
            own[identity] = min(own.get(identity, ticks), ticks)
        return HistogramPopulation.from_rows(own.items(), population.stored_grid), None
    combined = select(laps.c.player_id, laps.c.time_ticks).union_all(scores(context)).subquery()
    merged = select(combined.c.player_id, func.min(combined.c.time_ticks).label("time_ticks")).group_by(
        combined.c.player_id).subquery()
    frequencies = session.execute(select(merged.c.time_ticks, func.count()).group_by(
        merged.c.time_ticks).order_by(merged.c.time_ticks)).all()
    return HistogramPopulation.from_frequencies(frequencies, stored_grid=population.stored_grid), merged
