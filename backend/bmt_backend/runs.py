"""Server-issued race contracts and leaderboards over one verified PB per player."""

from __future__ import annotations

import math
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import Integer, cast, func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .identity_models import Player
from .track_models import (
    Board,
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

router = APIRouter(tags=["races"])
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
CHECKPOINT_RULES_TRANSITION = ("standing-5-road-gates-v12", "standing-5-road-gates-v13")


def leaderboard_session(request: Request):
    """Every population/count/window projection observes one database snapshot."""
    engine = request.app.state.engine
    if engine.dialect.name == "postgresql":
        with (
            engine.connect().execution_options(isolation_level="REPEATABLE READ") as connection,
            Session(connection) as session,
        ):
            session.execute(text("SET TRANSACTION READ ONLY"))
            yield session
    else:
        with request.app.state.session_factory() as session:
            yield session


BoardDB = Annotated[Session, Depends(leaderboard_session)]


class TicketRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version_id: str = Field(min_length=36, max_length=36)
    vehicle_id: str = Field(min_length=1, max_length=80)


class SubmitRun(BaseModel):
    model_config = ConfigDict(extra="forbid")
    ticket_id: str = Field(min_length=36, max_length=36)
    replay: dict


def board_manifest(version: TrackVersion, vehicle_id: str) -> dict:
    manifest = version.manifest
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
    # This rules-only correction keeps immutable road content and handling.
    # A different key creates a fresh board; historical PBs stay on the old one.
    if pinned["rules_key"] == CHECKPOINT_RULES_TRANSITION[0]:
        pinned["rules_key"] = CHECKPOINT_RULES_TRANSITION[1]
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
    }


@router.get("/manifest")
def manifest(request: Request) -> dict:
    try:
        return request.app.state.verifier.manifest()
    except RuntimeError:
        raise HTTPException(503, "Race verifier temporarily unavailable") from None


@router.post("/run-tickets", status_code=201)
def issue_ticket(payload: TicketRequest, request: Request, session: DB, player: Auth, key: Key) -> dict:
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
    validate_replay(payload.replay)
    body = {"ticket_id": payload.ticket_id, "replay_hash": digest(payload.replay)}
    old = replay_response(session, player.id, "submit_run", key, body)
    if old is not None:
        return old
    session.scalar(select(Player).where(Player.id == player.id).with_for_update())
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
    # Distinct tickets for the same player share one queue budget across API replicas.
    session.scalar(select(Player).where(Player.id == player.id).with_for_update())
    outstanding = session.scalar(
        select(func.count())
        .select_from(Run)
        .where(Run.player_id == player.id, Run.status.in_(("queued", "verifying")))
    )
    if outstanding >= 8:
        raise HTTPException(
            429, "Verification queue is full for this player; retry after a pending result completes"
        )
    from .resumes import validate_receipts
    validate_receipts(session, ticket.id, payload.replay)
    replay_hash = request.app.state.blobs.put_json(payload.replay)
    if replay_hash != body["replay_hash"]:
        raise HTTPException(503, "Replay storage hash mismatch")
    run = Run(ticket_id=ticket.id, player_id=player.id, board_id=ticket.board_id, replay_hash=replay_hash)
    session.add(run)
    session.flush()
    return commit_response(session, player.id, "submit_run", key, body, run_payload(run))


@router.get("/runs/{run_id}")
def get_run(run_id: str, session: DB, player: Auth) -> dict:
    run = session.scalar(select(Run).where(Run.id == run_id, Run.player_id == player.id))
    if run is None:
        raise HTTPException(404, "Run not found")
    return run_payload(run)


def public_board(session, board_id: str) -> Board:
    board = session.get(Board, board_id)
    if board is None:
        raise HTTPException(404, "Leaderboard not found")
    published_version(session, board.version_id)
    return board


def population(board_id: str):
    return (
        select(
            PersonalBest.player_id,
            Player.display_name,
            PersonalBest.run_id,
            PersonalBest.time_ticks,
            PersonalBest.achieved_at,
        )
        .join(Player, Player.id == PersonalBest.player_id)
        .where(PersonalBest.board_id == board_id, Player.disabled.is_(False))
    )


def ranked_population(board_id: str):
    return (
        population(board_id)
        .add_columns(
            func.rank().over(order_by=PersonalBest.time_ticks).label("rank"),
            func.row_number()
            .over(order_by=(PersonalBest.time_ticks, PersonalBest.player_id))
            .label("position"),
        )
        .subquery()
    )


@router.get("/boards/{board_id}")
def top(
    board_id: str,
    session: BoardDB,
    offset: int = Query(0, ge=0, le=10000),
    limit: int = Query(20, ge=1, le=100),
) -> dict:
    board = public_board(session, board_id)
    ranked = ranked_population(board_id)
    count = session.scalar(select(func.count()).select_from(ranked))
    rows = (
        session.execute(select(ranked).order_by(ranked.c.position).offset(offset).limit(limit))
        .mappings()
        .all()
    )
    return {
        "board_id": board_id,
        "manifest": board.manifest,
        "population": count,
        "items": [dict(row) for row in rows],
        "next_offset": offset + limit if offset + limit < count else None,
    }


@router.get("/track-versions/{version_id}/leaderboard")
def version_board(
    version_id: str, session: BoardDB, vehicle_id: str = Query("compact", max_length=80),
    offset: int = Query(0, ge=0, le=10000), limit: int = Query(20, ge=1, le=100),
) -> dict:
    version = published_version(session, version_id)
    pinned = board_manifest(version, vehicle_id)
    board_id = digest({"version_id": version.id, **pinned})
    if session.get(Board, board_id) is None:
        return {"board_id": board_id, "manifest": pinned, "population": 0, "items": [], "next_offset": None}
    return top(board_id, session, offset, limit)


@router.get("/boards/{board_id}/around-me")
def around_me(board_id: str, session: BoardDB, player: Auth, radius: int = Query(3, ge=1, le=25)) -> dict:
    public_board(session, board_id)
    ranked = ranked_population(board_id)
    count = session.scalar(select(func.count()).select_from(ranked))
    own = session.execute(select(ranked).where(ranked.c.player_id == player.id)).mappings().first()
    if own is None:
        return {
            "board_id": board_id,
            "population": count,
            "player": None,
            "items": [],
            "faster_than_percent": None,
        }
    rows = (
        session.execute(
            select(ranked)
            .where(ranked.c.position.between(max(1, own["position"] - radius), own["position"] + radius))
            .order_by(ranked.c.position)
        )
        .mappings()
        .all()
    )
    slower = session.scalar(
        select(func.count()).select_from(ranked).where(ranked.c.time_ticks > own["time_ticks"])
    )
    return {
        "board_id": board_id,
        "population": count,
        "player": dict(own),
        "items": [dict(row) for row in rows],
        "faster_than_percent": round(100 * slower / (count - 1), 3) if count > 1 else None,
    }


@router.get("/boards/{board_id}/histogram")
def histogram(board_id: str, session: BoardDB, bins: int = Query(10, ge=1, le=100)) -> dict:
    public_board(session, board_id)
    entries = population(board_id).subquery()
    count, minimum, maximum = session.execute(
        select(func.count(), func.min(entries.c.time_ticks), func.max(entries.c.time_ticks)).select_from(
            entries
        )
    ).one()
    if count == 0:
        return {
            "board_id": board_id,
            "population": 0,
            "minimum_ticks": None,
            "maximum_ticks": None,
            "bins": [],
        }
    width = max(1, math.ceil((maximum - minimum + 1) / bins))
    bucket = cast(func.floor((entries.c.time_ticks - minimum) / width), Integer)
    grouped = dict(
        session.execute(
            select(bucket.label("bucket"), func.count()).select_from(entries).group_by(bucket)
        ).all()
    )
    occupied_bins = (maximum - minimum) // width + 1
    return {
        "board_id": board_id,
        "population": count,
        "minimum_ticks": minimum,
        "maximum_ticks": maximum,
        "bins": [
            {
                "from_ticks": minimum + i * width,
                "to_ticks_exclusive": minimum + (i + 1) * width,
                "count": grouped.get(i, 0),
            }
            for i in range(occupied_bins)
        ],
    }


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
    return {
        "run_id": run.id,
        "board_id": board_id,
        "time_ticks": run.time_ticks,
        "replay": request.app.state.blobs.get_json(run.replay_hash),
    }
