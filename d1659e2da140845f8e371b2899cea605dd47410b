"""Daily verified results; no all-time PB or raw-run aggregation on reads."""
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query, Request, Response
from sqlalchemy import func, select, tuple_

from .cursors import decode_cursor, encode_cursor
from .daily_standings_models import DailyBest
from .discovery_models import TrackOfDay
from .discovery_projection import insert
from .discovery_v3 import hydrate, query_budget
from .identity_models import Player
from .runs import BoardDB, board_manifest
from .security import bearer, current_player
from .track_models import RunTicket, TrackVersion, digest, now

router = APIRouter(tags=["track of the day"])
DAY = 86400


@router.get("/v1/track-of-the-day/lap-standings")
def flying_standings(request: Request, response: Response, background: BackgroundTasks, session: BoardDB,
                     day: int = Query(..., ge=0), version_id: str = Query(..., min_length=36, max_length=36),
                     vehicle_id: str = Query("compact", max_length=80), limit: int = Query(10, ge=1, le=50),
                     cursor: str = Query("", max_length=400), around: bool = False,
                     lap_ticks: int | None = Query(None, ge=1, le=216000), credentials=Depends(bearer)):
    from .daily_lap_standings import build

    context, population = _elimination_context(request, response, background, session, day, version_id, vehicle_id, credentials)
    if population is None:
        return context
    artificial = request.app.state.settings.test_drivers_enabled
    player = current_player(request, credentials, session) if credentials else None
    return build(session, context, population, player, limit=limit, cursor=cursor,
                 around=around, candidate=lap_ticks, artificial=artificial)


@router.get("/v1/track-of-the-day/limits")
def elimination_limits(request: Request, response: Response, background: BackgroundTasks, session: BoardDB,
                       day: int = Query(..., ge=0), version_id: str = Query(..., min_length=36, max_length=36),
                       vehicle_id: str = Query("compact", max_length=80), credentials=Depends(bearer)):
    context, _ = _elimination_context(request, response, background, session, day, version_id, vehicle_id, credentials)
    return context


def _elimination_context(request, response, background, session, day, version_id, vehicle_id, credentials):
    from .daily_elimination import POLICY, cutoffs
    from .histogram_http import schedule_demand
    from .histogram_snapshots import load_snapshot

    player = current_player(request, credentials, session) if credentials else None
    response.headers["Cache-Control"] = "private, no-store"
    stamp = now()
    chosen = session.get(TrackOfDay, stamp // DAY)
    if chosen is None:
        raise HTTPException(503, "TRACK_OF_DAY_PREPARING")
    if day != chosen.day or version_id != chosen.version_id:
        raise HTTPException(409, "TRACK_OF_DAY_CHANGED")
    if not hydrate(session, request, [{"version_id": version_id}], player):
        raise HTTPException(404, "TRACK_OF_DAY_UNAVAILABLE")
    pinned = board_manifest(session.get(TrackVersion, version_id), vehicle_id)
    include_artificial = request.app.state.settings.test_drivers_enabled
    snapshot = load_snapshot(session, version_id, vehicle_id, include_artificial)
    expected_board = digest({"version_id": version_id, **pinned, "comparison_population": "all"})
    if snapshot is not None and (snapshot[2][1].stored_grid or {}).get("board_id") != expected_board:
        snapshot = None
    schedule_demand(request, background, version_id, vehicle_id, include_artificial, unavailable=snapshot is None)
    if snapshot is None:
        # Return normally so the bounded refresh-interest task is executed.
        response.status_code = 503
        response.headers["Retry-After"] = "5"
        return {"detail": "LAP_LIMITS_PREPARING"}, None
    generation, _, (_, laps) = snapshot
    limits = cutoffs(laps)
    if not limits:
        response.status_code = 409
        return {"detail": "NO_FLYING_LAP_TIMES"}, None
    return {"policy": POLICY, "day": chosen.day, "version_id": version_id, "vehicle_id": vehicle_id,
            "ends_at": (chosen.day+1)*DAY, "server_now": stamp, "tick_rate": 120,
            "generation": generation, "manifest": pinned, "population": laps.cumulative[-1], "cutoffs": limits}, laps


def eligible_day(session, ticket, board, submitted_at):
    """Tickets and submissions must both arrive inside the featured UTC day.

    Delayed verification still belongs to that original day. Client clocks,
    verification completion time and an earlier all-time PB never select it.
    """
    if (board.manifest.get("purpose") == "creator_test" or board.manifest.get("test_population")
            or board.manifest.get("laps") != 5 or submitted_at < ticket.created_at):
        return None
    day = ticket.created_at // DAY
    if submitted_at // DAY != day:
        return None
    chosen = session.get(TrackOfDay, day)
    player = session.get(Player, ticket.player_id)
    if (chosen is None or chosen.version_id != board.version_id or player is None
            or player.disabled or player.deleted_at is not None or player.is_test_driver):
        return None
    return day


def needs_verification(session, ticket, board, ticks, submitted_at):
    day = eligible_day(session, ticket, board, submitted_at)
    if day is None:
        return False
    best = session.get(DailyBest, (day, board.id, ticket.player_id))
    return best is None or ticks < best.time_ticks


def accept_verified(session, run, board):
    if run.status != "verified" or not run.time_ticks or not 0 < run.time_ticks <= 216000:
        return False
    ticket = session.get(RunTicket, run.ticket_id)
    day = eligible_day(session, ticket, board, run.created_at) if (ticket and ticket.player_id == run.player_id
        and ticket.board_id == run.board_id == board.id) else None
    if day is None:
        return False
    values = {"day": day, "board_id": board.id, "player_id": run.player_id,
              "run_id": run.id, "time_ticks": run.time_ticks, "achieved_at": run.created_at}
    statement = insert(session, DailyBest).values(**values)
    session.execute(statement.on_conflict_do_update(index_elements=["day", "board_id", "player_id"],
        set_={key: values[key] for key in ("run_id", "time_ticks", "achieved_at")},
        where=DailyBest.time_ticks > run.time_ticks))
    return True


def population(day, board_id):
    return (select(DailyBest.player_id, Player.display_name, Player.country_code,
                   DailyBest.time_ticks, DailyBest.achieved_at)
        .join(Player, Player.id == DailyBest.player_id)
        .where(DailyBest.day == day, DailyBest.board_id == board_id,
               Player.disabled.is_(False), Player.deleted_at.is_(None), Player.is_test_driver.is_(False)))


@router.get("/v1/track-of-the-day/standings")
def standings(request: Request, response: Response, session: BoardDB,
              day: int = Query(..., ge=0), version_id: str = Query(..., min_length=36, max_length=36),
              vehicle_id: str = Query("compact", max_length=80), limit: int = Query(10, ge=1, le=50),
              cursor: str = Query("", max_length=400), credentials=Depends(bearer)):
    player = current_player(request, credentials, session) if credentials else None
    if session.bind.dialect.name == "sqlite":
        connection = session.connection()
        if not connection.connection.driver_connection.in_transaction:
            connection.exec_driver_sql("BEGIN")
    stamp = now()
    response.headers["Cache-Control"] = "private, no-store"
    with query_budget(session):
        chosen = session.get(TrackOfDay, stamp // DAY)
        if chosen is None:
            raise HTTPException(503, "TRACK_OF_DAY_PREPARING", headers={"Retry-After": "30"})
        if day != chosen.day or version_id != chosen.version_id:
            raise HTTPException(409, "TRACK_OF_DAY_CHANGED")
        if not hydrate(session, request, [{"version_id": version_id}], player):
            raise HTTPException(404, "TRACK_OF_DAY_UNAVAILABLE")
        version = session.get(TrackVersion, version_id)
        manifest = board_manifest(version, vehicle_id)
        bid = digest({"version_id": version_id, **manifest})
        query = population(day, bid)
        count = lambda *conditions: int(session.scalar(select(func.count()).select_from(
            query.where(*conditions).subquery())) or 0)
        total = count()
        window = query
        if cursor:
            anchor = decode_cursor(cursor)
            if (anchor.get("day") != day or anchor.get("board") != bid
                    or type(anchor.get("ticks")) is not int or not 0 < anchor["ticks"] <= 216000
                    or not isinstance(anchor.get("player"), str) or len(anchor["player"]) != 36):
                raise HTTPException(422, "INVALID_CURSOR")
            window = window.where(tuple_(DailyBest.time_ticks, DailyBest.player_id)
                                  > (anchor["ticks"], anchor["player"]))
        raw = session.execute(window.order_by(DailyBest.time_ticks, DailyBest.player_id).limit(limit+1)).mappings().all()
        leader = session.execute(query.order_by(DailyBest.time_ticks, DailyBest.player_id).limit(1)).mappings().first()
        leader_ticks = leader["time_ticks"] if leader else 0
        items, previous, rank = [], None, 0
        first_position = 1
        if raw:
            first_ticks, first_player = raw[0]["time_ticks"], raw[0]["player_id"]
            rank = count(DailyBest.time_ticks < first_ticks)+1
            first_position = rank+count(DailyBest.time_ticks == first_ticks, DailyBest.player_id < first_player)
        for index, row in enumerate(raw[:limit]):
            if previous is not None and row["time_ticks"] != previous:
                rank = first_position+index
            items.append({**row, "rank": rank, "gap_ticks": row["time_ticks"]-leader_ticks})
            previous = row["time_ticks"]
        own = session.execute(query.where(DailyBest.player_id == player.id)).mappings().first() if player else None
        if own:
            own = {**own, "rank": count(DailyBest.time_ticks < own["time_ticks"])+1,
                   "gap_ticks": own["time_ticks"]-leader_ticks}
        return {"day": day, "starts_at": day*DAY, "ends_at": (day+1)*DAY, "server_now": stamp,
                "version_id": version_id, "vehicle_id": vehicle_id, "board_id": bid,
                "tick_rate": manifest["tick_rate"], "population": total, "items": items, "player": own,
                "next_cursor": encode_cursor({"day": day, "board": bid, "ticks": items[-1]["time_ticks"],
                    "player": items[-1]["player_id"]}) if len(raw) > limit else None}
