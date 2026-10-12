"""Server-issued race contracts and leaderboards over one verified PB per player."""

from __future__ import annotations

import math
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import Integer, case, cast, func, select, text, tuple_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .board_cache import cached
from .contracts import current_manifest
from .cursors import decode_cursor, encode_cursor
from .db import get_session
from .histogram_population import HistogramPopulation
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .queueing import admit, check_capacity
from .security import bearer, current_player
from .test_population import check_scope
from .track_models import (
    Board,
    BoardTimeCount,
    PersonalBest,
    Run,
    RunTicket,
    Track,
    TrackVersion,
    commit_response,
    digest,
    now,
    replay_response,
)
from .tracks import DB, Auth, Key, published_version

router = APIRouter(route_class=ParsedJSONRoute, tags=["races"])
PINNED_FIELDS = (
    "engine_version",
    "verifier_version",
    "rules_key",
    "physics_version",
    "compiler_version",
    "track_schema",
    "replay_schema",
    "tick_rate",
    "laps",
)
MAX_FRAMES = 216000
CHECKPOINT_RULES_TRANSITION = ("standing-5-road-gates-v12", "standing-5-road-gates-v18")


def leaderboard_session(request: Request, credentials=Depends(bearer), session=Depends(get_session)):
    """Every population/count/window projection observes one database snapshot."""
    if credentials is not None:
        current_player(request,credentials,session)
    # Share the authenticated request's one connection and transaction. The
    # later Auth dependency reuses the request-scoped validated identity.
    session.commit()
    engine = request.app.state.engine
    if engine.dialect.name == "postgresql":
        session.connection(execution_options={"isolation_level":"REPEATABLE READ"})
        session.execute(text("SET TRANSACTION READ ONLY"))
    yield session


BoardDB = Annotated[Session, Depends(leaderboard_session)]


class TicketRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version_id: str = Field(min_length=36, max_length=36)
    vehicle_id: str = Field(min_length=1, max_length=80)
    purpose: Literal["race", "creator_test"] = "race"
    test_population: bool = False


class SubmitRun(BaseModel):
    model_config = ConfigDict(extra="forbid")
    ticket_id: str = Field(min_length=36, max_length=36)
    replay: dict


def board_manifest(version: TrackVersion, vehicle_id: str) -> dict:
    manifest = current_manifest(version.manifest)
    vehicle = manifest.get("vehicles", {}).get(vehicle_id)
    if vehicle is None:
        raise HTTPException(422, "Vehicle is not allowed by the server manifest")
    pinned = {
        **{field: manifest[field] for field in PINNED_FIELDS},
        "track_content_hash": manifest["track_content_hash"],
        "vehicle_id": vehicle_id,
        "handling_version": vehicle["handling_version"],
        "config_hash": vehicle["config_hash"],
    }
    return pinned


def _ticket_payload(ticket: RunTicket, board: Board) -> dict:
    return {
        "ticket_id": ticket.id,
        "board_id": board.id,
        "version_id": board.version_id,
        "manifest": board.manifest,
        "expires_at": ticket.expires_at,
    }


def run_payload(run: Run) -> dict:
    return {
        "run_id": run.id,
        "ticket_id": run.ticket_id,
        "board_id": run.board_id,
        "status": run.status,
        "created_at": run.created_at,
        "finished_at": run.finished_at,
        "time_ticks": run.time_ticks,
        "lap_ticks": run.lap_ticks,
        "failure_code": run.failure_code,
        "retryable": run.status == "failed" and run.failure_code in ("verifier_unavailable", "build_mismatch", "build_unavailable"),
        "poll_after_ms": pending_poll_ms(run),
    }


def pending_poll_ms(run, status=None):
    if (status or (run.status if run else "upload_pending")) not in ("queued", "verifying", "upload_pending"):
        return 0
    return 1000 if run is not None and now()-run.created_at < 10 else 2500


@router.get("/manifest")
def manifest(request: Request) -> dict:
    try:
        return request.app.state.verifier.manifest()
    except RuntimeError:
        raise HTTPException(503, "Race verifier temporarily unavailable") from None


@router.post("/run-tickets", status_code=201)
def issue_ticket(payload: TicketRequest, request: Request, session: DB, player: Auth, key: Key) -> dict:
    check_scope(request, payload.test_population, player)
    body = payload.model_dump()
    old = replay_response(session, player.id, "ticket", key, body)
    if old is not None:
        return old
    version = session.get(TrackVersion, payload.version_id)
    track = session.get(Track, version.track_id) if version else None
    if version is None or (version.state != "published" and track.owner_id != player.id):
        raise HTTPException(404, "Track version not found")
    if session.get(Player, track.owner_id).disabled:
        raise HTTPException(404, "Track version not found")
    if payload.purpose == "creator_test" and track.owner_id != player.id:
        raise HTTPException(403, "Only the creator can test this draft")
    if version.state == "validating":
        raise HTTPException(409, "TRACK_VALIDATION_PENDING")
    if version.state == "invalid" or not version.manifest:
        raise HTTPException(422, "INVALID_DOCUMENT: repair this revision before testing")
    pinned = board_manifest(version, payload.vehicle_id)
    try:
        active = request.app.state.verifier.manifest()
    except RuntimeError:
        raise HTTPException(503, "Race verifier temporarily unavailable") from None
    if (
        any(active.get(field) != pinned[field] for field in PINNED_FIELDS)
        or active.get("vehicles", {}).get(payload.vehicle_id)
        != version.manifest["vehicles"][payload.vehicle_id]
    ):
        raise HTTPException(
            409, "This version requires a different verifier build; upload and test a new version"
        )
    if payload.purpose == "creator_test":
        pinned = {**pinned, "purpose": "creator_test", "laps": 1}
    if payload.test_population:
        pinned = {**pinned, "test_population": True}
    board_id = digest({"version_id": version.id, **pinned})
    board = session.get(Board, board_id)
    if board is None:
        # Savepoint allows a concurrent first ticket to create the same board safely.
        try:
            with session.begin_nested():
                board = Board(
                    id=board_id, version_id=version.id, vehicle_id=payload.vehicle_id, manifest=pinned
                )
                session.add(board)
                session.flush()
        except IntegrityError:
            board = session.get(Board, board_id)
    ticket = RunTicket(player_id=player.id, board_id=board.id, expires_at=now() + 7200)
    session.add(ticket)
    session.flush()
    return commit_response(session, player.id, "ticket", key, body, _ticket_payload(ticket, board))


def validate_replay(replay: dict) -> None:
    from .verifier import VerificationError
    from .verifier import validate_replay as validate
    try:
        validate(replay)
    except VerificationError as exc:
        raise HTTPException(422, str(exc)) from None


@router.post("/runs", status_code=202)
def submit(payload: SubmitRun, request: Request, session: DB, player: Auth, key: Key) -> dict:
    from .replay_wire import unpack_replay
    payload.replay = unpack_replay(payload.replay)
    validate_replay(payload.replay)
    body = {"ticket_id": payload.ticket_id, "replay_hash": digest(payload.replay)}
    old = replay_response(session, player.id, "submit_run", key, body)
    if old is not None:
        return old
    # Check the immutable ticket before publishing, then release DB resources.
    ticket = session.get(RunTicket, payload.ticket_id)
    if ticket is None or ticket.player_id != player.id:
        raise HTTPException(404, "Run ticket not found")
    board = session.get(Board, ticket.board_id)
    check_scope(request, bool(board.manifest.get("test_population")), player)
    existing = session.scalar(select(Run).where(Run.ticket_id == ticket.id))
    if existing is not None:
        if existing.replay_hash != body["replay_hash"]:
            raise HTTPException(409, "Ticket already submitted with different replay content")
        return commit_response(session, player.id, "submit_run", key, body, run_payload(existing))
    # Expiry prevents first admission, never recovery of an already accepted
    # immutable submission after a lost response or prolonged network outage.
    if ticket.expires_at <= now():
        raise HTTPException(410, "Run ticket expired")
    check_capacity(session, player.id, request.app.state.settings.max_queued_runs)
    from .resumes import validate_receipts
    validate_receipts(session, ticket.id, payload.replay)
    owner_id = player.id
    session.rollback()
    replay_hash = request.app.state.blobs.put_json(payload.replay)
    if replay_hash != body["replay_hash"]:
        raise HTTPException(503, "Replay storage hash mismatch")
    session.scalar(select(Player).where(Player.id == owner_id).with_for_update())
    ticket = session.scalar(
        select(RunTicket)
        .where(RunTicket.id == payload.ticket_id, RunTicket.player_id == player.id)
        .with_for_update()
    )
    if ticket is None:
        raise HTTPException(404, "Run ticket not found")
    existing = session.scalar(select(Run).where(Run.ticket_id == ticket.id))
    if existing:
        if existing.replay_hash != body["replay_hash"]:
            raise HTTPException(409, "Ticket already submitted with different replay content")
        return commit_response(session, player.id, "submit_run", key, body, run_payload(existing))
    if ticket.expires_at <= now():
        raise HTTPException(410, "Run ticket expired")
    board = session.get(Board, ticket.board_id)
    check_scope(request, bool(board.manifest.get("test_population")), player)
    if board.manifest.get("purpose") == "creator_test":
        repeated = session.scalar(select(Run).where(Run.player_id == player.id,
            Run.board_id == ticket.board_id, Run.replay_hash == body["replay_hash"])
            .order_by(Run.created_at, Run.id).limit(1))
        if repeated is not None:
            return commit_response(session, player.id, "submit_run", key, body, run_payload(repeated))
    check_capacity(session, player.id, request.app.state.settings.max_queued_runs)
    validate_receipts(session, ticket.id, payload.replay)
    admit(session, player.id, request.app.state.settings.max_queued_runs)
    validate_receipts(session, ticket.id, payload.replay, settle=True)
    run = Run(ticket_id=ticket.id, player_id=player.id, board_id=ticket.board_id, replay_hash=replay_hash)
    session.add(run)
    session.flush()
    return commit_response(session, player.id, "submit_run", key, body, run_payload(run))


@router.get("/runs/status")
def run_statuses(session: DB, player: Auth, ids: list[str] = Query(max_length=32)) -> dict:
    from .rivalry_models import RivalryTicket
    rows = session.execute(select(Run, RivalryTicket.outcome, RivalryTicket.slot)
        .outerjoin(RivalryTicket, RivalryTicket.ticket_id == Run.ticket_id)
        .where(Run.player_id == player.id, Run.id.in_(ids))).all()
    return {"items": [{**run_payload(run), "outcome": outcome, "slot": slot} for run, outcome, slot in rows], "poll_after_ms": 2500}


@router.get("/runs/{run_id}")
def get_run(run_id: str, session: DB, player: Auth) -> dict:
    run = session.scalar(select(Run).where(Run.id == run_id, Run.player_id == player.id))
    if run is None:
        raise HTTPException(404, "Run not found")
    from .rivalry_models import RivalryTicket
    binding = session.get(RivalryTicket, run.ticket_id)
    return {**run_payload(run), "outcome": binding.outcome if binding else None, "slot": binding.slot if binding else None}


@router.post("/runs/{run_id}/retry")
def retry_run(run_id: str, request: Request, session: DB, player: Auth, key: Key) -> dict:
    scope = f"retry_run:{run_id}"
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    session.scalar(select(Player).where(Player.id == player.id).with_for_update())
    run = session.scalar(select(Run).where(Run.id == run_id, Run.player_id == player.id).with_for_update())
    if run is None:
        raise HTTPException(404, "Run not found")
    check_scope(request, bool(session.get(Board, run.board_id).manifest.get("test_population")), player)
    if run.status == "failed" and run.failure_code in ("verifier_unavailable", "build_mismatch", "build_unavailable"):
        board = session.get(Board, run.board_id)
        try:
            active = request.app.state.verifier.manifest()
        except RuntimeError:
            raise HTTPException(503, "Verifier temporarily unavailable; the original replay is retained") from None
        creator_test = board.manifest.get("purpose") == "creator_test"
        compatible = {**active, "laps":1} if creator_test else active
        vehicle = active.get("vehicles", {}).get(board.vehicle_id, {})
        if (any(board.manifest.get(field) != compatible.get(field) for field in PINNED_FIELDS)
                or any(board.manifest.get(field) != vehicle.get(field) for field in ("handling_version", "config_hash"))):
            raise HTTPException(409, "CONTRACT_UNSUPPORTED: this saved attempt requires its original verifier build")
        admit(session, player.id, request.app.state.settings.max_queued_runs)
        run.status, run.attempts, run.lease_until, run.lease_token = "queued", 0, 0, None
        run.failure_code, run.finished_at = None, None
    elif run.status == "rejected":
        raise HTTPException(409, "INVALID_REPLAY: complete a new valid attempt")
    return commit_response(session, player.id, scope, key, {}, run_payload(run))


def public_board(session, board_id: str) -> Board:
    board = session.get(Board, board_id)
    if board is None or board.manifest.get("purpose") == "creator_test" or board.manifest.get("test_population"):
        raise HTTPException(404, "Leaderboard not found")
    published_version(session, board.version_id)
    return board


def population(board_id: str):
    return (
        select(
            PersonalBest.player_id,
            Player.display_name,
            Player.country_code,
            PersonalBest.run_id,
            PersonalBest.time_ticks,
            PersonalBest.achieved_at,
        )
        .join(Player, Player.id == PersonalBest.player_id)
        .where(PersonalBest.board_id == board_id, Player.disabled.is_(False), Player.is_test_driver.is_(False))
    )


def population_count(session, board_id, *conditions):
    if not conditions:
        return session.scalar(select(Board.public_count).where(Board.id == board_id))
    return population_count_query(session, board_id, *conditions)


def population_count_query(session, board_id, *conditions):
    return session.scalar(select(func.count()).select_from(population(board_id).where(*conditions).subquery()))


def rank_rows(session, board_id, rows, first_position):
    result, previous_time, rank = [], None, 0
    for index, source in enumerate(rows):
        row = dict(source)
        if row["time_ticks"] != previous_time:
            rank = (tick_count(session, board_id, BoardTimeCount.time_ticks < row["time_ticks"]) + 1
                    if index == 0 else first_position + index)
            previous_time = row["time_ticks"]
        result.append({**row, "rank": rank, "position": first_position + index})
    return result


@router.get("/boards/{board_id}")
def top(
    board_id: str,
    session: BoardDB,
    offset: int = Query(0, ge=0, le=10000),
    limit: int = Query(20, ge=1, le=100),
    cursor: str = "",
) -> dict:
    board = public_board(session, board_id)
    count = population_count(session, board_id)
    statement = population(board_id)
    if cursor:
        position = decode_cursor(cursor)
        if type(position.get("ticks")) is not int or not isinstance(position.get("player"), str) or len(position["player"]) > 36:
            raise HTTPException(422, "INVALID_CURSOR")
        before = tuple_(PersonalBest.time_ticks, PersonalBest.player_id) <= (position["ticks"], position["player"])
        if position.get("board") == board_id and position.get("revision") == board.stats_revision and type(position.get("position")) is int:
            offset = position["position"]
        else:
            offset = tick_count(session, board_id, BoardTimeCount.time_ticks < position["ticks"]) + population_count(
                session, board_id, PersonalBest.time_ticks == position["ticks"], PersonalBest.player_id <= position["player"])
        statement = statement.where(~before)
    raw = session.execute(statement.order_by(PersonalBest.time_ticks, PersonalBest.player_id).offset(0 if cursor else offset).limit(limit+1)).mappings().all()
    rows = rank_rows(session, board_id, raw[:limit], offset + 1)
    return {
        "board_id": board_id,
        "manifest": board.manifest,
        "population": count,
        "items": [dict(row) for row in rows],
        "next_offset": offset + limit if offset + limit < count else None,
        "next_cursor": encode_cursor({"ticks": rows[-1]["time_ticks"], "player": rows[-1]["player_id"],
            "board":board_id,"revision":board.stats_revision,"position":offset+len(rows)}) if len(raw) > limit else None,
    }


@router.get("/track-versions/{version_id}/leaderboard")
def version_board(
    version_id: str, session: BoardDB, vehicle_id: str = Query("compact", max_length=80),
    offset: int = Query(0, ge=0, le=10000), limit: int = Query(20, ge=1, le=100),
    cursor: str = Query("", max_length=400),
) -> dict:
    version = published_version(session, version_id)
    pinned = board_manifest(version, vehicle_id)
    board_id = digest({"version_id": version.id, **pinned})
    if session.get(Board, board_id) is None:
        return {"board_id": board_id, "manifest": pinned, "population": 0, "items": [], "next_offset": None}
    return top(board_id, session, offset, limit, cursor)


@router.get("/boards/{board_id}/around-me")
def around_me(board_id: str, session: BoardDB, player: Auth, radius: int = Query(3, ge=1, le=25)) -> dict:
    public_board(session, board_id)
    count = population_count(session, board_id)
    own = session.execute(population(board_id).where(PersonalBest.player_id == player.id)).mappings().first()
    if own is None:
        return {
            "board_id": board_id,
            "population": count,
            "player": None,
            "items": [],
            "faster_than_percent": None,
        }
    ticks = own["time_ticks"]
    before = tuple_(PersonalBest.time_ticks, PersonalBest.player_id) < (ticks, player.id)
    after = tuple_(PersonalBest.time_ticks, PersonalBest.player_id) > (ticks, player.id)
    position = tick_count(session, board_id, BoardTimeCount.time_ticks < ticks) + population_count(
        session, board_id, PersonalBest.time_ticks == ticks, PersonalBest.player_id < player.id) + 1
    predecessors = session.execute(population(board_id).where(before).order_by(PersonalBest.time_ticks.desc(), PersonalBest.player_id.desc()).limit(radius)).mappings().all()
    successors = session.execute(population(board_id).where(after).order_by(PersonalBest.time_ticks, PersonalBest.player_id).limit(radius)).mappings().all()
    rows = rank_rows(session, board_id, list(reversed(predecessors)) + [own] + list(successors), position - len(predecessors))
    own = rows[len(predecessors)]
    slower = tick_count(session, board_id, BoardTimeCount.time_ticks > ticks)
    return {
        "board_id": board_id,
        "population": count,
        "player": dict(own),
        "items": [dict(row) for row in rows],
        "faster_than_percent": round(100 * slower / (count - 1), 3) if count > 1 else None,
    }


@router.get("/boards/{board_id}/histogram")
def histogram(board_id: str, session: BoardDB, bins: int = Query(10, ge=1, le=100),
              metric: Literal["race", "best_lap"] = "race") -> dict:
    board = public_board(session, board_id)
    from .histogram_snapshots import load_snapshot
    snapshot = load_snapshot(session, board.version_id, board.vehicle_id, False)
    if snapshot is None:
        raise HTTPException(503, "Comparison snapshot is being prepared")
    generation, _, populations = snapshot
    result = population_comparison(session, ("public-histogram", board_id, generation),
        populations[0 if metric == "race" else 1], board_id, metric, bins, "", None, None, None)
    return {**{name: result[name] for name in ("population", "minimum_ticks", "maximum_ticks", "bins", "metric")},
            "board_id": board_id}


def histogram_query(board_id, session, bins, *, test_population=False, metric="race"):
    frequency = BoardTimeCount.all_count if test_population else BoardTimeCount.public_count
    entries = select(BoardTimeCount.time_ticks, frequency.label("count")).where(
        BoardTimeCount.board_id == board_id, frequency > 0).subquery()
    if metric == "best_lap":
        entries = best_lap_frequencies(board_id, session, test_population=test_population)
    return histogram_from_entries(board_id, session, bins, metric, entries)


def histogram_from_entries(board_id, session, bins, metric, entries, *, candidate=None, frame_from=None, frame_to=None):
    count, minimum, maximum = session.execute(
        select(func.coalesce(func.sum(entries.c.count), 0), func.min(entries.c.time_ticks), func.max(entries.c.time_ticks)).select_from(
            entries
        )
    ).one()
    count = int(count)
    if count == 0:
        return {
            "board_id": board_id,
            "population": 0,
            "minimum_ticks": None,
            "maximum_ticks": None,
            "bins": [],
            "metric": metric,
        }
    # Reserve the completed result's domain before its PB upload verifies. It
    # changes only the bin geometry, never the verified population/counts.
    start = min(minimum, candidate if candidate is not None else minimum,
                frame_from if frame_from is not None else minimum)
    end = max(maximum + 1, candidate + 1 if candidate is not None else maximum + 1,
              frame_to if frame_to is not None else maximum + 1)
    width = max(1, math.ceil((end - start) / bins))
    bucket = cast(func.floor((entries.c.time_ticks - start) / width), Integer)
    grouped = {int(bucket): int(frequency) for bucket, frequency in
        session.execute(
            select(bucket.label("bucket"), func.sum(entries.c.count)).select_from(entries).group_by(bucket)
        ).all()
    }
    occupied_bins = (end - start - 1) // width + 1
    return {
        "board_id": board_id,
        "metric": metric,
        "population": count,
        "minimum_ticks": minimum,
        "maximum_ticks": maximum,
        "bins": [
            {
                "from_ticks": start + i * width,
                "to_ticks_exclusive": start + (i + 1) * width,
                "count": grouped.get(i, 0),
            }
            for i in range(occupied_bins)
        ],
    }


def best_lap_frequencies(board_id, session, *, test_population=False):
    bests = best_lap_times(board_id, session, test_population=test_population)
    return select(bests.c.time_ticks, func.count().label("count")).group_by(bests.c.time_ticks).subquery()


def best_lap_times(board_id, session, *, test_population=False):
    """Read one durable flying PB per eligible driver; never scan attempts."""
    from .track_models import LapBestState, LapPersonalBest
    state = session.get(LapBestState, board_id)
    if state is not None and not state.complete:
        raise RuntimeError("Flying-lap PB backfill is incomplete")
    statement = select(LapPersonalBest.player_id, LapPersonalBest.time_ticks).join(
        Player, Player.id == LapPersonalBest.player_id).join(PersonalBest,
        (PersonalBest.board_id == LapPersonalBest.board_id) & (PersonalBest.player_id == LapPersonalBest.player_id)).where(
        LapPersonalBest.board_id == board_id, Player.disabled.is_(False))
    if not test_population:
        statement = statement.where(Player.is_test_driver.is_(False))
    elif state is not None:
        from sqlalchemy import or_
        statement = statement.where(or_(Player.is_test_driver.is_(False), LapPersonalBest.source_created_at >= state.cutoff))
    return statement.subquery()


def comparison_position(entries, session, ticks, own_ticks):
    if ticks is None:
        return None
    total, faster = session.execute(select(
        func.coalesce(func.sum(entries.c.count), 0),
        func.coalesce(func.sum(case((entries.c.time_ticks < ticks, entries.c.count), else_=0)), 0)
    )).one()
    # Compare the result with other drivers, replacing the player's existing
    # contribution rather than counting them twice when this race is slower.
    opponents = int(total) - int(own_ticks is not None)
    if opponents <= 0:
        return None
    faster = int(faster) - int(own_ticks is not None and own_ticks < ticks)
    position, population = faster + 1, opponents + 1
    return {"position": position, "population": population,
            "top_percent": max(1, math.ceil(position * 100 / population)),
            "candidate_ticks": ticks}


@router.get("/track-versions/{version_id}/results-comparison")
def results_comparison(version_id: str, vehicle_id: str, request: Request, session: BoardDB, player: Auth,
                       bins: int = Query(16, ge=1, le=100),
                       race_ticks: int | None = Query(None, ge=1, le=MAX_FRAMES),
                       lap_ticks: int | None = Query(None, ge=1, le=MAX_FRAMES),
                       race_from_ticks: int | None = Query(None, ge=1, le=MAX_FRAMES),
                       race_to_ticks: int | None = Query(None, ge=2, le=MAX_FRAMES * 2),
                       lap_from_ticks: int | None = Query(None, ge=1, le=MAX_FRAMES),
                       lap_to_ticks: int | None = Query(None, ge=2, le=MAX_FRAMES * 2)):
    """One deduplicated field of all available drivers, never a UI source choice."""
    for start, end in ((race_from_ticks, race_to_ticks), (lap_from_ticks, lap_to_ticks)):
        if (start is None) != (end is None) or start is not None and end <= start:
            raise HTTPException(422, "Histogram frame requires ordered start/end bounds")
    version = published_version(session, version_id)
    pinned = board_manifest(version, vehicle_id)
    public_id = digest({"version_id": version.id, **pinned})
    include_artificial = request.app.state.settings.test_drivers_enabled
    test_id = digest({"version_id": version.id, **pinned, "test_population": True})
    from .histogram_snapshots import load_snapshot
    snapshot = load_snapshot(session, version.id, vehicle_id, include_artificial)
    if snapshot is None:
        raise HTTPException(503, "Comparison snapshot is being prepared")
    generation, revision, (races, laps) = snapshot
    population_key = ("comparison-population", public_id, test_id if include_artificial else None, generation)
    board_id = digest({"version_id": version.id, **pinned, "comparison_population":"all"})
    race = population_comparison(session, population_key, races, board_id, "race", bins, player.id,
                                 race_ticks, race_from_ticks, race_to_ticks)
    lap = population_comparison(session, population_key, laps, board_id, "best_lap", bins, player.id,
                                lap_ticks, lap_from_ticks, lap_to_ticks)
    return {"board_id": board_id, "population_scope": "all",
            "stats_revision": revision, "race": race, "best_lap": lap}


def comparison_populations(session, board_ids, public_id, test_id, include_artificial):
    """Reconstruct the deduplicated field only on a database revision change."""
    race_statement = select(PersonalBest.player_id, func.min(PersonalBest.time_ticks).label("time_ticks")).join(
        Player, Player.id == PersonalBest.player_id).where(PersonalBest.board_id.in_(board_ids), Player.disabled.is_(False))
    if not include_artificial:
        race_statement = race_statement.where(Player.is_test_driver.is_(False))
    races = race_statement.group_by(PersonalBest.player_id).subquery()
    public_laps = best_lap_times(public_id, session)
    laps = public_laps
    if include_artificial:
        test_laps = best_lap_times(test_id, session, test_population=True)
        combined = select(public_laps.c.player_id, public_laps.c.time_ticks).union_all(
            select(test_laps.c.player_id, test_laps.c.time_ticks)).subquery()
        laps = select(combined.c.player_id, func.min(combined.c.time_ticks).label("time_ticks")).group_by(combined.c.player_id).subquery()
    return (HistogramPopulation.from_rows(session.execute(select(races)).all()),
            HistogramPopulation.from_rows(session.execute(select(laps)).all()))


def population_comparison(session, key, population, board_id, metric, bins, player_id, candidate, start, end):
    start, end = population.frame(candidate, start, end)
    stored = population.stored_grid
    stored_bins = stored["bins"] if stored else []
    compatible = bins == 16 and (not stored_bins or
        start == stored_bins[0]["from_ticks"] and end in (population.ticks[-1]+1, stored_bins[-1]["to_ticks_exclusive"]))
    grid = stored if stored is not None and compatible else cached(
        session, ("comparison-grid", key, metric, bins, start, end),
        lambda: population.histogram(board_id, metric, bins, start, end))
    # Never put a player's markers/placement in the shared cached grid.
    result = {**grid, "bins": [dict(item) for item in grid["bins"]]}
    own = population.own.get(player_id)
    result["own_best_ticks"] = own
    result["opponent_count"] = result["population"] - int(own is not None)
    result["comparison"] = population.position(candidate or own, own)
    return result


def tick_count(session, board_id, *conditions):
    return session.scalar(select(func.coalesce(func.sum(BoardTimeCount.public_count), 0)).where(
        BoardTimeCount.board_id == board_id, *conditions))


@router.get("/boards/{board_id}/ghosts/{player_id}")
def ghost(board_id: str, player_id: str, request: Request, session: BoardDB, player: Auth) -> dict:
    # Raw canonical controls are personal data: a public ghost will need derived position samples.
    if player.id != player_id:
        raise HTTPException(404, "Personal replay not found")
    public_board(session, board_id)
    best = session.execute(population(board_id).where(PersonalBest.player_id == player_id)).first()
    if best is None:
        raise HTTPException(404, "Verified ghost not found")
    run = session.get(Run, best.run_id)
    result = {
        "run_id": run.id,
        "board_id": board_id,
        "time_ticks": run.time_ticks,
    }
    replay_hash = run.replay_hash
    session.commit()  # Release the snapshot connection before storage pin/IO.
    return {**result, "replay": request.app.state.blobs.get_json(replay_hash)}
