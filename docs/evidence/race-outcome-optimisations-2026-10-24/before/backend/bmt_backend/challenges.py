"""Discoverable competitions and private invitations over verified pinned races."""
from __future__ import annotations

import html
import re
import secrets
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import and_, case, exists, or_, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import aliased

from .challenge_models import (
    Challenge,
    ChallengeMember,
    ChallengeStage,
    ChallengeStageTicket,
    ChallengeTicket,
)
from .cursors import decode_cursor, encode_cursor
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .runs import PINNED_FIELDS, _ticket_payload, board_manifest
from .security import bearer, current_player
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
from .tracks import DB, Auth, Key, published_version, track_payload

router = APIRouter(route_class=ParsedJSONRoute, tags=["challenges"])
preview_router = APIRouter(tags=["challenge invitations"])


@preview_router.get("/.well-known/assetlinks.json")
def app_links(request: Request):
    settings = request.app.state.settings
    fingerprints = settings.android_app_link_certificates
    if not fingerprints or any(not re.fullmatch(r"(?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}", value) for value in fingerprints):
        raise HTTPException(404, "Android App Links are not configured")
    return JSONResponse([{"relation": ["delegate_permission/common.handle_all_urls"],
                          "target": {"namespace": "android_app", "package_name": settings.android_app_link_package,
                                     "sha256_cert_fingerprints": list(fingerprints)}}],
                        headers={"Cache-Control": "public, max-age=300"})


class Create(BaseModel):
    model_config = ConfigDict(extra="forbid")
    version_id: str = Field(min_length=36, max_length=36)
    vehicle_id: str = Field(min_length=1, max_length=80)
    mode: Literal["beat", "group", "3x3"] = "beat"
    version_ids: list[str] | None = Field(default=None, min_length=2, max_length=5)
    duration_seconds: Literal[86400, 259200, 604800] = 604800
    attempt_limit: int | None = Field(default=None, strict=True)
    visibility: Literal["private", "public"] = "private"
    source_run_id: str | None = Field(default=None, min_length=36, max_length=36)
    source_ticket_id: str | None = Field(default=None, min_length=36, max_length=36)

    @model_validator(mode="after")
    def one_source(self):
        if self.attempt_limit not in (None, 1, 3, 5):
            raise ValueError("Choose 1, 3, 5 or unlimited tries")
        if self.source_run_id and self.source_ticket_id:
            raise ValueError("Choose one result reference")
        if self.mode == "3x3":
            if (not self.version_ids or len(set(self.version_ids)) != 3
                    or self.version_ids[0] != self.version_id or any(len(v) != 36 for v in self.version_ids)
                    or self.attempt_limit != 3):
                raise ValueError("3x3 requires three distinct tracks and three tries per track")
        elif self.version_ids is not None and (len(set(self.version_ids)) != len(self.version_ids)
                or self.version_ids[0] != self.version_id or any(len(v) != 36 for v in self.version_ids)):
            raise ValueError("Choose two to five distinct tracks, starting with the opening track")
        return self


class Rematch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    duration_seconds: Literal[86400, 259200, 604800] = 604800


def real_player(player):
    if player.is_test_driver:
        raise HTTPException(403, "Artificial drivers cannot enter challenges")


def available(session, code, *, lock=False):
    if not re.fullmatch(r"[A-F0-9]{16}", code):
        raise HTTPException(404, "Challenge not found")
    query = select(Challenge).where(Challenge.code == code)
    challenge = session.scalar(query.with_for_update() if lock else query)
    if challenge is None or session.get(Player, challenge.creator_id).disabled:
        raise HTTPException(404, "Challenge not found")
    board = session.get(Board, challenge.board_id)
    version = published_version(session, board.version_id)
    if session.get(Track, version.track_id).hidden:
        raise HTTPException(404, "Challenge track unavailable")
    if challenge.is_series:
        from .challenge_series import check_tracks
        check_tracks(session, challenge)
    return challenge


def compatible(request, pinned):
    try:
        active = request.app.state.verifier.manifest()
    except RuntimeError:
        raise HTTPException(503, "Race verifier temporarily unavailable") from None
    config = active.get("vehicles", {}).get(pinned["vehicle_id"], {})
    if (any(active.get(field) != pinned.get(field) for field in PINNED_FIELDS)
            or pinned.get("handling_version") != config.get("handling_version")
            or pinned.get("config_hash") != config.get("config_hash")):
        raise HTTPException(409, "Challenge requires a different game build")


def check_participant_blocks(session, player_id, challenge):
    from .community import check_creator, is_blocked
    board = session.get(Board, challenge.board_id)
    check_creator(session, player_id, session.get(Track, session.get(TrackVersion, board.version_id).track_id).owner_id)
    if challenge.is_series:
        from .challenge_series import check_tracks
        check_tracks(session, challenge, player_id)
    peers = session.scalars(select(ChallengeMember.player_id).where(ChallengeMember.challenge_id == challenge.id)).all()
    if any(is_blocked(session, player_id, peer, mutual=True) for peer in {challenge.creator_id, *peers}):
        raise HTTPException(403, "PLAYER_BLOCKED")


def prepare_board(session, request, version_id, vehicle_id):
    version = published_version(session, version_id)
    if session.get(Track, version.track_id).hidden:
        raise HTTPException(404, "Challenge track unavailable")
    pinned = board_manifest(version, vehicle_id)
    compatible(request, pinned)
    if pinned["laps"] != 5:
        raise HTTPException(409, "Challenges require five laps")
    board_id = digest({"version_id": version.id, **pinned})
    board = session.get(Board, board_id)
    if board is None:
        try:
            with session.begin_nested():
                session.add(Board(id=board_id, version_id=version.id, vehicle_id=vehicle_id, manifest=pinned))
                session.flush()
        except IntegrityError:
            pass
        board = session.get(Board, board_id)
    return board


def standings(session, challenge):
    board = session.get(Board, challenge.board_id)
    members = session.execute(select(ChallengeMember, Player).join(Player)
        .where(ChallengeMember.challenge_id == challenge.id, Player.disabled.is_(False),
               Player.is_test_driver.is_(False)).order_by(ChallengeMember.joined_at, Player.id)).all()
    times = sorted(member.time_ticks for member, _ in members if member.time_ticks is not None)
    rows = [{"id": player.id, "name": player.display_name, "country_code": player.country_code,
             "ticks": member.time_ticks, "run_id": member.run_id,
             "ms": round(member.time_ticks * 1000 / board.manifest["tick_rate"]) if member.time_ticks else None,
             "rank": 1 + sum(value < member.time_ticks for value in times) if member.time_ticks else None}
            for member, player in members]
    return sorted(rows, key=lambda row: (row["ticks"] is None, row["ticks"] or 0, row["id"]))


def snapshot(session, request, challenge, player_id=""):
    board = session.get(Board, challenge.board_id)
    version = session.get(TrackVersion, board.version_id)
    track = session.get(Track, version.track_id)
    creator = session.get(Player, challenge.creator_id)
    from .community import check_creator, is_blocked
    check_creator(session, player_id, track.owner_id)
    if is_blocked(session, player_id, creator.id, mutual=True):
        raise HTTPException(403, "PLAYER_BLOCKED")
    if challenge.is_series:
        from .challenge_series import check_tracks
        check_tracks(session, challenge, player_id)
    rows = standings(session, challenge)
    current = now()
    pending = session.scalar(select(Run.id).join(ChallengeTicket, ChallengeTicket.ticket_id == Run.ticket_id)
        .where(ChallengeTicket.challenge_id == challenge.id, Run.status.in_(("queued", "verifying"))).limit(1))
    state = "cancelled" if challenge.cancelled else "active" if current < challenge.ends_at else "settling" if pending else "complete"
    target = session.get(Run, challenge.target_run_id) if challenge.target_run_id else None
    member = session.get(ChallengeMember, (challenge.id, player_id)) if player_id else None
    attempts_used = member.attempts_used if member else 0
    from .economy import challenge_rewards
    value = {"id": challenge.id, "code": challenge.code, "mode": challenge.mode, "state": state,
            "track_count": challenge.track_count, "visibility": challenge.visibility, "capacity": 2 if challenge.mode == "beat" else 20,
            "rewards": challenge_rewards(session, challenge.id, player_id, current),
            "creator_id": creator.id, "creator": creator.display_name, "self_id": player_id,
            "joined": any(row["id"] == player_id for row in rows), "vehicle_id": board.vehicle_id,
            "created_at": challenge.created_at, "ends_at": challenge.ends_at, "server_now": current,
            "remaining_seconds": max(0, challenge.ends_at-current), "manifest": board.manifest,
            "attempt_limit": challenge.attempt_limit,
            "attempts_used": attempts_used,
            "attempts_remaining": max(0, challenge.attempt_limit-attempts_used) if challenge.attempt_limit is not None else None,
            "target_ticks": challenge.target_ticks,
            "target_ms": round(challenge.target_ticks*1000/board.manifest["tick_rate"]) if challenge.target_ticks else None,
            "target_id": target.player_id if target else None, "standings": rows,
            "entry": track_payload(version, track, session.get(Player, track.owner_id).display_name,
                                   request.app.state.settings.public_base_url),
            "share_url": request.app.state.settings.public_base_url.rstrip("/")+"/c/"+challenge.code}
    if challenge.is_series:
        from .challenge_series import decorate
        return decorate(session, request, challenge, value, player_id)
    return value


def source_for(session, board, player_id, source_run_id=None, source_ticket_id=None):
    if source_ticket_id:
        ticket = session.get(RunTicket, source_ticket_id)
        if ticket is None or ticket.player_id != player_id or ticket.board_id != board.id:
            raise HTTPException(404, "Race result not found")
        run = session.scalar(select(Run).where(Run.ticket_id == source_ticket_id))
        if run is None or run.status in ("queued", "verifying"):
            raise HTTPException(409, "Result is still being verified")
        source_run_id = run.id
    elif not source_run_id:
        best = session.get(PersonalBest, (board.id, player_id))
        source_run_id = best.run_id if best else None
    run = session.get(Run, source_run_id) if source_run_id else None
    if (run is None or run.player_id != player_id or run.board_id != board.id
            or run.status != "verified" or not run.time_ticks):
        raise HTTPException(409, "Race to set a verified time first")
    return run


def ensure_ghost(session, request, run, board):
    """Store existing optional poses without re-simulating a verified race."""
    if run.ghost_hash:
        return
    run_id, replay_hash, ticks = run.id, run.replay_hash, run.time_ticks
    # Commit only a prepared board before potentially lengthy verifier/blob IO.
    session.commit()
    from .verifier import validate_ghost
    try:
        ghost = request.app.state.blobs.get_json(replay_hash).get("ghost")
        if not ghost:
            return  # A verified target remains usable without a recording.
        validate_ghost(ghost, ticks)
        ghost_hash = request.app.state.blobs.put_json(ghost)
    except (RuntimeError, OSError, ValueError):
        raise HTTPException(503, "Ghost could not be prepared. Try again") from None
    session.execute(update(Run).where(Run.id == run_id, Run.status == "verified", Run.ghost_hash.is_(None))
                    .values(ghost_hash=ghost_hash))
    session.flush()


@router.get("/challenges/sources")
def sources(request: Request, session: DB, player: Auth,
            version_id: str = Query(min_length=36, max_length=36), vehicle_id: str = Query(max_length=80),
            ticket_id: str | None = Query(default=None, min_length=36, max_length=36)):
    real_player(player)
    board = prepare_board(session, request, version_id, vehicle_id)
    best = session.get(PersonalBest, (board.id, player.id))
    run = session.scalar(select(Run).where(Run.ticket_id == ticket_id, Run.player_id == player.id,
                                          Run.board_id == board.id)) if ticket_id else session.get(Run, best.run_id) if best else None
    session.commit()
    return {"run_id": run.id if run else None, "status": run.status if run else "not_set",
            "ms": round(run.time_ticks*1000/board.manifest["tick_rate"]) if run and run.time_ticks else None}


def create_record(session, request, player, payload, key, scope, body):
    if payload.visibility == "public":
        from .community import require_terms
        require_terms(session, player.id)
    board = prepare_board(session, request, payload.version_id, payload.vehicle_id)
    from .community import check_creator
    check_creator(session, player.id, session.get(Track, session.get(TrackVersion, payload.version_id).track_id).owner_id)
    source = source_for(session, board, player.id, payload.source_run_id, payload.source_ticket_id) if payload.mode == "beat" or payload.source_run_id or payload.source_ticket_id else None
    if source:
        ensure_ghost(session, request, source, board)
        # Blob IO/verification released the snapshot. Recheck availability/build.
        board = prepare_board(session, request, payload.version_id, payload.vehicle_id)
        source = source_for(session, board, player.id, source.id)
    boards = [prepare_board(session, request, v, payload.vehicle_id) for v in payload.version_ids] if payload.version_ids else []
    if boards:
        track_ids = [session.get(TrackVersion, b.version_id).track_id for b in boards]
        if len(set(track_ids)) != len(boards):
            raise HTTPException(422, "Choose distinct tracks")
        for track_id in track_ids:
            track = session.get(Track, track_id)
            if track.archived:
                raise HTTPException(404, "Challenge track unavailable")
            check_creator(session, player.id, track.owner_id)
    challenge = Challenge(code=secrets.token_hex(8).upper(), creator_id=player.id, board_id=board.id,
        mode=payload.mode, visibility=payload.visibility, target_run_id=source.id if source else None,
        target_ticks=source.time_ticks if source and payload.mode == "beat" and not boards else None,
        attempt_limit=payload.attempt_limit, track_count=len(boards) or 1, ends_at=now()+payload.duration_seconds)
    session.add(challenge)
    session.flush()
    session.add(ChallengeMember(challenge_id=challenge.id, player_id=player.id,
                               attempts_used=1 if source else 0,
                               run_id=source.id if source and not boards else None, time_ticks=source.time_ticks if source and not boards else None))
    session.flush()
    if boards:
        for ordinal, stage_board in enumerate(boards):
            session.add(ChallengeStage(challenge_id=challenge.id, ordinal=ordinal, board_id=stage_board.id))
        session.flush()
        from .challenge_series import add_member
        add_member(session, challenge, player.id, source)
    return commit_response(session, player.id, scope, key, body, snapshot(session, request, challenge, player.id))


@router.post("/challenges", status_code=201)
def create(payload: Create, request: Request, session: DB, player: Auth, key: Key):
    real_player(player)
    # Unlimited is the existing contract, including persisted pre-migration keys.
    omitted = {"version_ids"} if payload.version_ids is None else set()
    omitted |= {"attempt_limit"} if payload.attempt_limit is None else set()
    if payload.visibility == "private":
        omitted.add("visibility")  # Preserve retry identities from older clients.
    body = payload.model_dump(exclude=omitted)
    old = replay_response(session, player.id, "challenge_create", key, body)
    return old if old is not None else create_record(session, request, player, payload, key, "challenge_create", body)


@router.get("/challenges")
def inbox(request: Request, session: DB, player: Auth,
          folder: Literal["discover", "friends", "received", "sent"] = "received",
          search: str = Query(default="", max_length=80), mode: Literal["all", "beat", "group", "3x3"] = "all",
          vehicle: str = Query(default="", max_length=80), sort: Literal["ending", "newest"] = "ending",
          cursor: str | None = Query(default=None, max_length=800)):
    return challenge_list(request, session, player, folder, search, mode, vehicle, sort, cursor)


@router.get("/challenges/discover")
def public_discovery(request: Request, session: DB, credentials=Depends(bearer),
          search: str = Query(default="", max_length=80), mode: Literal["all", "beat", "group", "3x3"] = "all",
          vehicle: str = Query(default="", max_length=80), sort: Literal["ending", "newest"] = "ending",
          cursor: str | None = Query(default=None, max_length=800)):
    player = current_player(request, credentials, session) if credentials else None
    return challenge_list(request, session, player, "discover", search, mode, vehicle, sort, cursor)


def challenge_list(request, session, player, folder, search, mode, vehicle, sort, cursor):
    if player:
        real_player(player)
    if player is None and folder != "discover":
        raise HTTPException(401, "SIGN_IN_REQUIRED")
    player_id = player.id if player else ""
    author = aliased(Player)
    track_author = aliased(Player)
    query = (select(Challenge).join(Board, Board.id == Challenge.board_id)
        .join(TrackVersion, TrackVersion.id == Board.version_id).join(Track, Track.id == TrackVersion.track_id)
        .join(author, author.id == Challenge.creator_id).join(track_author, track_author.id == Track.owner_id)
        .where(author.disabled.is_(False), author.deleted_at.is_(None), author.is_test_driver.is_(False),
               track_author.disabled.is_(False), track_author.is_test_driver.is_(False),
               Track.hidden.is_(False), TrackVersion.state == "published"))
    series = request.query_params.get("series") == "1"
    if not series:
        query = query.where(Challenge.mode != "3x3")
    if request.query_params.get("custom_tracks") != "1":
        query = query.where(or_(Challenge.track_count == 1, Challenge.mode == "3x3"))
    public = folder in ("discover", "friends")
    if public:
        query = query.where(Challenge.visibility == "public", Track.archived.is_(False), Challenge.cancelled.is_(False),
            Challenge.ends_at > now(), Challenge.member_count < case((Challenge.mode == "beat", 2), else_=20))
        # Only actionable, compatible races appear; never fetch blobs or run a verifier here.
        try:
            active = request.app.state.verifier.manifest()
        except RuntimeError:
            raise HTTPException(503, "Race verifier temporarily unavailable") from None
        for field in PINNED_FIELDS:
            value = active.get(field)
            column = Board.manifest[field].as_integer() if type(value) is int else Board.manifest[field].as_string()
            query = query.where(column == value)
        configurations = [and_(Board.vehicle_id == car,
            Board.manifest["handling_version"].as_string() == config.get("handling_version"),
            Board.manifest["config_hash"].as_string() == config.get("config_hash"))
            for car, config in active.get("vehicles", {}).items()]
        query = query.where(or_(*configurations) if configurations else False)
        if player:
            query = query.where(Challenge.creator_id != player.id,
                ~exists().where(ChallengeMember.challenge_id == Challenge.id, ChallengeMember.player_id == player.id))
        if folder == "friends":
            from .news_models import Friendship
            query = query.where(exists().where(Friendship.accepted.is_(True), or_(
                and_(Friendship.low_id == player_id, Friendship.high_id == Challenge.creator_id),
                and_(Friendship.high_id == player_id, Friendship.low_id == Challenge.creator_id))))
    else:
        query = query.where(exists().where(ChallengeMember.challenge_id == Challenge.id,
            ChallengeMember.player_id == player_id),
            Challenge.creator_id == player_id if folder == "sent" else Challenge.creator_id != player_id)
    if player:
        from .community_models import PlayerBlock
        blocked = select(PlayerBlock.blocked_id).where(PlayerBlock.player_id == player.id)
        blockers = select(PlayerBlock.player_id).where(PlayerBlock.blocked_id == player.id)
        query = query.where(Challenge.creator_id.not_in(blocked), Challenge.creator_id.not_in(blockers),
                            Track.owner_id.not_in(blocked))
        if public:
            query = query.where(~exists().where(ChallengeMember.challenge_id == Challenge.id,
                or_(ChallengeMember.player_id.in_(blocked), ChallengeMember.player_id.in_(blockers))))
    search = search.strip()
    if search:
        term = "%" + search.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
        query = query.where(or_(TrackVersion.name.ilike(term, escape="\\"), author.display_name.ilike(term, escape="\\")))
    if mode != "all":
        query = query.where(Challenge.mode == mode)
    if vehicle:
        query = query.where(Board.vehicle_id == vehicle)
    ascending = public and sort == "ending"
    order_column = Challenge.ends_at if ascending else Challenge.created_at
    context = {"folder": folder, "player": player_id, "search": search, "mode": mode, "vehicle": vehicle, "sort": sort}
    if series:
        context["series"] = 1
    if request.query_params.get("custom_tracks") == "1":
        context["custom_tracks"] = 1
    if cursor is not None:
        position = decode_cursor(cursor)
        if (set(position) != {"at", "id", *context} or type(position["at"]) is not int
                or type(position["id"]) is not str or len(position["id"]) != 36
                or any(position.get(key) != value for key, value in context.items())):
            raise HTTPException(422, "INVALID_CURSOR")
        query = query.where(or_(order_column > position["at"] if ascending else order_column < position["at"],
                               (order_column == position["at"]) & (Challenge.id > position["id"])))
    limit = 20 if public else 50
    challenges = session.scalars(query.order_by(order_column.asc() if ascending else order_column.desc(), Challenge.id)
                                .limit(limit+1)).all()
    items = []
    for challenge in challenges[:limit]:
        try:
            items.append(snapshot(session, request, challenge, player_id))
        except HTTPException as exc:
            if not challenge.is_series or exc.status_code not in (403, 404):
                raise
    last = challenges[limit-1] if len(challenges) > limit else None
    next_cursor = encode_cursor({"at": last.ends_at if ascending else last.created_at, "id": last.id,
                                 **context}) if last else None
    return {"items": items, "next_cursor": next_cursor}


@router.get("/challenges/{code}")
def invitation(code: str, request: Request, session: DB, credentials=Depends(bearer)):
    player = current_player(request, credentials, session) if credentials else None
    return snapshot(session, request, available(session, code), player.id if player else "")


@router.get("/challenges/{code}/me")
def view(code: str, request: Request, session: DB, player: Auth):
    real_player(player)
    return snapshot(session, request, available(session, code), player.id)


@router.post("/challenges/{code}/join")
def join(code: str, request: Request, session: DB, player: Auth, key: Key):
    real_player(player)
    scope = "challenge_join:"+code
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    challenge = available(session, code, lock=True)
    check_participant_blocks(session, player.id, challenge)
    compatible(request, session.get(Board, challenge.board_id).manifest)
    if challenge.is_series:
        from .challenge_series import check_tracks
        check_tracks(session, challenge, player.id, request)
    if session.get(ChallengeMember, (challenge.id, player.id)) is None:
        capacity = 2 if challenge.mode == "beat" else 20
        if challenge.cancelled or now() >= challenge.ends_at:
            raise HTTPException(410, "Challenge has ended")
        reserved = session.execute(update(Challenge).where(Challenge.id == challenge.id,
            Challenge.member_count < capacity, Challenge.ends_at > now(), Challenge.cancelled.is_(False))
            .values(member_count=Challenge.member_count+1)).rowcount
        if not reserved:
            raise HTTPException(409, "Challenge is full")
        session.add(ChallengeMember(challenge_id=challenge.id, player_id=player.id))
        session.flush()
        if challenge.is_series:
            from .challenge_series import add_member
            add_member(session, challenge, player.id)
    return commit_response(session, player.id, scope, key, {}, snapshot(session, request, challenge, player.id))


@router.post("/challenges/{code}/tickets", status_code=201)
def ticket(code: str, request: Request, session: DB, player: Auth, key: Key,
           stage: int | None = Query(default=None, ge=0, le=4)):
    real_player(player)
    scope = "challenge_ticket:"+code+(":"+str(stage) if stage is not None else "")
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    challenge = available(session, code, lock=True)
    check_participant_blocks(session, player.id, challenge)
    # Another request with the same key may have committed while this one waited.
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    if session.get(ChallengeMember, (challenge.id, player.id)) is None:
        raise HTTPException(403, "Join this challenge first")
    if challenge.cancelled or now() >= challenge.ends_at:
        raise HTTPException(410, "Challenge has ended")
    if challenge.mode == "beat" and not challenge.is_series and player.id == challenge.creator_id:
        raise HTTPException(409, "Share this challenge to invite an opponent")
    if (challenge.is_series) != (stage is not None):
        raise HTTPException(422, "Choose one of the challenge tracks" if challenge.is_series else "This challenge has one track")
    stage_member = None
    if stage is not None:
        from .challenge_series import reserve
        board, stage_member = reserve(session, challenge, player.id, stage)
    else:
        board = session.get(Board, challenge.board_id)
    compatible(request, board.manifest)
    reservation = update(ChallengeMember).where(ChallengeMember.challenge_id == challenge.id,
                                               ChallengeMember.player_id == player.id)
    if challenge.attempt_limit is not None and stage is None:
        reservation = reservation.where(ChallengeMember.attempts_used < challenge.attempt_limit)
    if not session.execute(reservation.values(attempts_used=ChallengeMember.attempts_used+1)).rowcount:
        raise HTTPException(409, "No tries remaining")
    member = session.get(ChallengeMember, (challenge.id, player.id))
    issued = RunTicket(player_id=player.id, board_id=board.id, expires_at=min(now()+7200, challenge.ends_at))
    session.add(issued)
    session.flush()
    session.add(ChallengeTicket(ticket_id=issued.id, challenge_id=challenge.id))
    session.flush()
    if stage is not None:
        session.add(ChallengeStageTicket(ticket_id=issued.id, ordinal=stage))
        member = stage_member
    return commit_response(session, player.id, scope, key, {}, {**_ticket_payload(issued, board), "challenge_code": code,
        "attempt_limit": challenge.attempt_limit, "attempts_used": member.attempts_used,
        "attempts_remaining": max(0, challenge.attempt_limit-member.attempts_used) if challenge.attempt_limit is not None else None})


def accept_verified(session, run, *, acceptance=None):
    binding = acceptance.challenge if acceptance else session.get(ChallengeTicket, run.ticket_id)
    if binding is None or binding.outcome is not None:
        return
    challenge = session.scalar(select(Challenge).where(Challenge.id == binding.challenge_id).with_for_update())
    if challenge.cancelled or not challenge.created_at <= run.created_at < challenge.ends_at:
        binding.outcome = {"counted": False}
        return
    member = session.get(ChallengeMember, (challenge.id, run.player_id))
    player = session.get(Player, run.player_id)
    if member is None or player.disabled or player.is_test_driver:
        binding.outcome = {"counted": False}
        return
    if challenge.is_series:
        from .challenge_series import accept
        accept(session, challenge, binding, run, member)
        return
    prior = member.time_ticks
    improved = prior is None or run.time_ticks < prior
    if improved:
        member.run_id, member.time_ticks = run.id, run.time_ticks
        session.flush()
    rows = standings(session, challenge)
    own = next(row for row in rows if row["id"] == run.player_id)
    board = session.get(Board, challenge.board_id)
    binding.outcome = {"counted": True, "improved": improved, "before_ticks": prior, "after": own,
        "ms": round(run.time_ticks*1000/board.manifest["tick_rate"]),
        "gap_ms": round((run.time_ticks-challenge.target_ticks)*1000/board.manifest["tick_rate"]) if challenge.target_ticks else None,
        "beaten": run.time_ticks < challenge.target_ticks if challenge.target_ticks else any(
            row["ticks"] is not None and row["id"] != run.player_id for row in rows) and all(
            row["ticks"] is None or row["id"] == run.player_id or run.time_ticks < row["ticks"] for row in rows)}


@router.get("/challenge-results/{ticket_id}")
def result(ticket_id: str, request: Request, session: DB, player: Auth):
    real_player(player)
    own = session.get(RunTicket, ticket_id)
    binding = session.get(ChallengeTicket, ticket_id)
    if own is None or binding is None or own.player_id != player.id:
        raise HTTPException(404, "Challenge result not found")
    challenge = session.get(Challenge, binding.challenge_id)
    available(session, challenge.code)
    run = session.scalar(select(Run).where(Run.ticket_id == ticket_id))
    status = run.status if run else "expired" if now() >= own.expires_at else "upload_pending"
    from .runs import pending_poll_ms
    return {"status": status, "failure_code": run.failure_code if run else None, "outcome": binding.outcome,
            "poll_after_ms": pending_poll_ms(run,status),
            "challenge": snapshot(session, request, challenge, player.id)}


@router.get("/challenges/{code}/ghost")
def ghost(code: str, request: Request, session: DB, credentials=Depends(bearer),
          stage: int | None = Query(default=None, ge=0, le=4), metadata: bool = False, expected_run_id: str = "", encoding: str = "json"):
    challenge = available(session, code)
    viewer = current_player(request, credentials, session) if credentials else None
    if viewer:
        check_participant_blocks(session, viewer.id, challenge)
    if challenge.cancelled:
        raise HTTPException(410, "Challenge was cancelled")
    if challenge.is_series:
        if stage is None:
            raise HTTPException(422, "Choose one of the challenge tracks")
        from .challenge_models import ChallengeStageMember
        candidates = session.scalars(select(ChallengeStageMember).join(Player).where(
            ChallengeStageMember.challenge_id == challenge.id, ChallengeStageMember.ordinal == stage,
            ChallengeStageMember.time_ticks.is_not(None), Player.disabled.is_(False), Player.is_test_driver.is_(False))
            .order_by(ChallengeStageMember.time_ticks, ChallengeStageMember.player_id)).all()
        run_id = candidates[0].run_id if candidates else None
    else:
        rows = standings(session, challenge)
        run_id = challenge.target_run_id if challenge.mode == "beat" else rows[0]["run_id"] if rows else None
    run = session.get(Run, run_id) if run_id else None
    if run is None or not run.ghost_hash or session.get(Player, run.player_id).disabled:
        raise HTTPException(404, "Ghost unavailable")
    run_id, ghost_hash, owner_id = run.id, run.ghost_hash, run.player_id
    session.commit()
    from .ghost_http import recording_response
    return recording_response(request, run_id, ghost_hash, owner_id, metadata=metadata, expected_run_id=expected_run_id, encoding=encoding)


@router.post("/challenges/{code}/cancel")
def cancel(code: str, request: Request, session: DB, player: Auth, key: Key):
    real_player(player)
    scope = "challenge_cancel:"+code
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    challenge = available(session, code, lock=True)
    if challenge.creator_id != player.id:
        raise HTTPException(403, "Only the creator can cancel this challenge")
    challenge.cancelled = True
    return commit_response(session, player.id, scope, key, {}, snapshot(session, request, challenge, player.id))


@router.post("/challenges/{code}/rematch", status_code=201)
def rematch(code: str, payload: Rematch, request: Request, session: DB, player: Auth, key: Key):
    real_player(player)
    scope, body = "challenge_rematch:"+code, payload.model_dump()
    old = replay_response(session, player.id, scope, key, body)
    if old is not None:
        return old
    challenge = available(session, code)
    if challenge.is_series:
        raise HTTPException(409, "Create a new multi-track challenge to race again")
    member = session.get(ChallengeMember, (challenge.id, player.id))
    if member is None or member.time_ticks is None or challenge.cancelled:
        raise HTTPException(409, "Set a verified time before rematching")
    if ((challenge.mode == "beat" and member.time_ticks >= challenge.target_ticks)
            or (challenge.mode == "group" and standings(session, challenge)[0]["ticks"] < member.time_ticks)):
        raise HTTPException(409, "Beat the leading time before rematching")
    board = session.get(Board, challenge.board_id)
    created = Create(version_id=board.version_id, vehicle_id=board.vehicle_id, source_run_id=member.run_id,
                     mode="beat", duration_seconds=payload.duration_seconds, attempt_limit=challenge.attempt_limit,
                     visibility=challenge.visibility)
    return create_record(session, request, player, created, key, scope, body)


@preview_router.get("/c/{code}", response_class=HTMLResponse)
def preview(code: str, request: Request, session: DB):
    value = snapshot(session, request, available(session, code))
    title = html.escape(" / ".join(stage["entry"]["name"] for stage in value["stages"])) if value.get("stages") else html.escape(value["entry"]["name"])
    name = html.escape(value["creator"])
    target = f'{len(value["stages"])} tracks - lowest total time wins' if value.get("stages") else f'{value["target_ms"]/1000:.3f} s' if value["target_ms"] else "Group challenge"
    state = "Invitation open" if value["state"] == "active" else value["state"].capitalize()
    vehicle = html.escape(value["vehicle_id"].replace("_", " ").title())
    limit = value["stages"][0]["attempt_limit"] if value.get("stages") else value["attempt_limit"]
    tries = (f"{limit} tries"+(" per track" if value.get("stages") else " per driver")) if limit is not None else "Unlimited tries"
    return HTMLResponse(f'''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{title} — Beat my track</title>
<meta property="og:title" content="{name} challenges you on {title}">
<meta property="og:description" content="{target} · Five laps · {vehicle}">
<style>body{{background:#080f16;color:#f1f4f3;font:20px system-ui;margin:0;min-height:100vh;display:grid;place-items:center}}
main{{background:#101e29;padding:40px;border-radius:12px;max-width:480px;margin:20px}}small{{color:#a4bac7}}h1{{margin:24px 0 8px}}
a{{display:block;padding:16px;background:#ffd348;color:#080f16;text-decoration:none;border-radius:5px;margin-top:24px}}
code{{font-size:18px;user-select:all}}.time{{font-size:48px;font-weight:700;margin:24px 0}}</style>
<main><small>BEAT MY TRACK · {state}</small><h1>{title}</h1><p>{name} challenges you</p><p class="time">{target}</p>
<p>Five laps · {vehicle} ? {tries}</p><a href="beatmytrack://challenge/{code}">Open Beat my track</a>
<p><small>Race → Challenges → Enter code</small><br><code>{code}</code></p></main></html>''',
                        headers={"Cache-Control": "no-store", "X-Robots-Tag": "noindex", "Referrer-Policy": "no-referrer"})
