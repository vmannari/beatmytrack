"""Unlisted invitations over pinned contracts and canonically verified results."""
from __future__ import annotations

import html
import re
import secrets
from typing import Literal

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import or_, select, update
from sqlalchemy.exc import IntegrityError

from .challenge_models import Challenge, ChallengeMember, ChallengeTicket
from .cursors import decode_cursor, encode_cursor
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .runs import PINNED_FIELDS, _ticket_payload, board_manifest
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
    mode: Literal["beat", "group"] = "beat"
    duration_seconds: Literal[86400, 259200, 604800] = 604800
    source_run_id: str | None = Field(default=None, min_length=36, max_length=36)


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
    rows = standings(session, challenge)
    current = now()
    pending = session.scalar(select(Run.id).join(ChallengeTicket, ChallengeTicket.ticket_id == Run.ticket_id)
        .where(ChallengeTicket.challenge_id == challenge.id, Run.status.in_(("queued", "verifying"))).limit(1))
    state = "cancelled" if challenge.cancelled else "active" if current < challenge.ends_at else "settling" if pending else "complete"
    target = session.get(Run, challenge.target_run_id) if challenge.target_run_id else None
    return {"id": challenge.id, "code": challenge.code, "mode": challenge.mode, "state": state,
            "creator_id": creator.id, "creator": creator.display_name, "self_id": player_id,
            "joined": any(row["id"] == player_id for row in rows), "vehicle_id": board.vehicle_id,
            "created_at": challenge.created_at, "ends_at": challenge.ends_at, "server_now": current,
            "remaining_seconds": max(0, challenge.ends_at-current), "manifest": board.manifest,
            "target_ticks": challenge.target_ticks,
            "target_ms": round(challenge.target_ticks*1000/board.manifest["tick_rate"]) if challenge.target_ticks else None,
            "target_id": target.player_id if target else None, "standings": rows,
            "entry": track_payload(version, track, session.get(Player, track.owner_id).display_name,
                                   request.app.state.settings.public_base_url),
            "share_url": request.app.state.settings.public_base_url.rstrip("/")+"/c/"+challenge.code}


def source_for(session, board, player_id, source_run_id=None):
    if not source_run_id:
        best = session.get(PersonalBest, (board.id, player_id))
        source_run_id = best.run_id if best else None
    run = session.get(Run, source_run_id) if source_run_id else None
    if (run is None or run.player_id != player_id or run.board_id != board.id
            or run.status != "verified" or not run.time_ticks):
        raise HTTPException(409, "Race to set a verified time first")
    return run


def ensure_ghost(session, request, run, board):
    """Older normal PBs have inputs only. Derive poses without holding SQL locks."""
    if run.ghost_hash:
        return
    run_id, replay_hash, ticks = run.id, run.replay_hash, run.time_ticks
    version = session.get(TrackVersion, board.version_id)
    document_hash, vehicle, pinned = version.content_hash, board.vehicle_id, dict(board.manifest)
    # Commit only a prepared board before potentially lengthy verifier/blob IO.
    session.commit()
    from .verifier import GodotVerifier, validate_ghost
    adapter = request.app.state.verifier
    options = {"capture_ghost": True} if isinstance(adapter, GodotVerifier) else {}
    try:
        proof = adapter.verify_run(request.app.state.blobs.get_json(document_hash),
                                   request.app.state.blobs.get_json(replay_hash), vehicle, **options)
        ghost = proof.get("ghost")
        validate_ghost(ghost, ticks)
        if proof.get("time_ticks") != ticks or any(proof.get("manifest", {}).get(k) != pinned[k] for k in PINNED_FIELDS):
            raise RuntimeError("Ghost differs from verified result")
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
    board = prepare_board(session, request, payload.version_id, payload.vehicle_id)
    source = source_for(session, board, player.id, payload.source_run_id) if payload.mode == "beat" or payload.source_run_id else None
    if source:
        ensure_ghost(session, request, source, board)
        # Blob IO/verification released the snapshot. Recheck availability/build.
        board = prepare_board(session, request, payload.version_id, payload.vehicle_id)
        source = source_for(session, board, player.id, source.id)
    challenge = Challenge(code=secrets.token_hex(8).upper(), creator_id=player.id, board_id=board.id,
        mode=payload.mode, target_run_id=source.id if source else None,
        target_ticks=source.time_ticks if source and payload.mode == "beat" else None, ends_at=now()+payload.duration_seconds)
    session.add(challenge)
    session.flush()
    session.add(ChallengeMember(challenge_id=challenge.id, player_id=player.id,
                               run_id=source.id if source else None, time_ticks=source.time_ticks if source else None))
    session.flush()
    return commit_response(session, player.id, scope, key, body, snapshot(session, request, challenge, player.id))


@router.post("/challenges", status_code=201)
def create(payload: Create, request: Request, session: DB, player: Auth, key: Key):
    real_player(player)
    body = payload.model_dump()
    old = replay_response(session, player.id, "challenge_create", key, body)
    return old if old is not None else create_record(session, request, player, payload, key, "challenge_create", body)


@router.get("/challenges")
def inbox(request: Request, session: DB, player: Auth,
          folder: Literal["received", "sent"] = "received", cursor: str | None = Query(default=None, max_length=400)):
    real_player(player)
    query = select(Challenge).join(ChallengeMember, ChallengeMember.challenge_id == Challenge.id).where(
        ChallengeMember.player_id == player.id, Challenge.creator_id == player.id if folder == "sent" else Challenge.creator_id != player.id)
    if cursor is not None:
        position = decode_cursor(cursor)
        if (set(position) != {"at", "id", "folder", "player"} or type(position["at"]) is not int
                or type(position["id"]) is not str or len(position["id"]) != 36
                or position["folder"] != folder or position["player"] != player.id):
            raise HTTPException(422, "INVALID_CURSOR")
        query = query.where(or_(Challenge.created_at < position["at"],
                               (Challenge.created_at == position["at"]) & (Challenge.id > position["id"])))
    challenges = session.scalars(query.order_by(Challenge.created_at.desc(), Challenge.id).limit(51)).all()
    items = []
    for challenge in challenges[:50]:
        try:
            available(session, challenge.code)
        except HTTPException as error:
            if error.status_code == 404:
                continue
            raise
        items.append(snapshot(session, request, challenge, player.id))
    next_cursor = encode_cursor({"at": challenges[49].created_at, "id": challenges[49].id,
                                 "folder": folder, "player": player.id}) if len(challenges) > 50 else None
    return {"items": items, "next_cursor": next_cursor}


@router.get("/challenges/{code}")
def invitation(code: str, request: Request, session: DB):
    return snapshot(session, request, available(session, code))


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
    compatible(request, session.get(Board, challenge.board_id).manifest)
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
    return commit_response(session, player.id, scope, key, {}, snapshot(session, request, challenge, player.id))


@router.post("/challenges/{code}/tickets", status_code=201)
def ticket(code: str, request: Request, session: DB, player: Auth, key: Key):
    real_player(player)
    scope = "challenge_ticket:"+code
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    challenge = available(session, code, lock=True)
    if session.get(ChallengeMember, (challenge.id, player.id)) is None:
        raise HTTPException(403, "Join this challenge first")
    if challenge.cancelled or now() >= challenge.ends_at:
        raise HTTPException(410, "Challenge has ended")
    if challenge.mode == "beat" and player.id == challenge.creator_id:
        raise HTTPException(409, "Share this challenge to invite an opponent")
    board = session.get(Board, challenge.board_id)
    compatible(request, board.manifest)
    issued = RunTicket(player_id=player.id, board_id=board.id, expires_at=min(now()+7200, challenge.ends_at))
    session.add(issued)
    session.flush()
    session.add(ChallengeTicket(ticket_id=issued.id, challenge_id=challenge.id))
    return commit_response(session, player.id, scope, key, {}, {**_ticket_payload(issued, board), "challenge_code": code})


def accept_verified(session, run):
    binding = session.get(ChallengeTicket, run.ticket_id)
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
        "beaten": run.time_ticks < challenge.target_ticks if challenge.target_ticks else own["rank"] == 1}


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
    return {"status": status, "failure_code": run.failure_code if run else None, "outcome": binding.outcome,
            "poll_after_ms": 2500 if status in ("queued", "verifying", "upload_pending") else 0,
            "challenge": snapshot(session, request, challenge, player.id)}


@router.get("/challenges/{code}/ghost")
def ghost(code: str, request: Request, session: DB):
    challenge = available(session, code)
    if challenge.cancelled:
        raise HTTPException(410, "Challenge was cancelled")
    rows = standings(session, challenge)
    run_id = challenge.target_run_id if challenge.mode == "beat" else rows[0]["run_id"] if rows else None
    run = session.get(Run, run_id) if run_id else None
    if run is None or not run.ghost_hash or session.get(Player, run.player_id).disabled:
        raise HTTPException(404, "Ghost unavailable")
    run_id, ghost_hash = run.id, run.ghost_hash
    session.commit()
    return {"run_id": run_id, "recording": request.app.state.blobs.get_json(ghost_hash)}


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
    member = session.get(ChallengeMember, (challenge.id, player.id))
    if member is None or member.time_ticks is None or challenge.cancelled:
        raise HTTPException(409, "Set a verified time before rematching")
    if ((challenge.mode == "beat" and member.time_ticks >= challenge.target_ticks)
            or (challenge.mode == "group" and standings(session, challenge)[0]["ticks"] < member.time_ticks)):
        raise HTTPException(409, "Beat the leading time before rematching")
    board = session.get(Board, challenge.board_id)
    created = Create(version_id=board.version_id, vehicle_id=board.vehicle_id, source_run_id=member.run_id,
                     mode="beat", duration_seconds=payload.duration_seconds)
    return create_record(session, request, player, created, key, scope, body)


@preview_router.get("/c/{code}", response_class=HTMLResponse)
def preview(code: str, request: Request, session: DB):
    value = snapshot(session, request, available(session, code))
    title = html.escape(value["entry"]["name"])
    name = html.escape(value["creator"])
    target = f'{value["target_ms"]/1000:.3f} s' if value["target_ms"] else "Group challenge"
    state = "Invitation open" if value["state"] == "active" else value["state"].capitalize()
    vehicle = html.escape(value["vehicle_id"].replace("_", " ").title())
    return HTMLResponse(f'''<!doctype html><html lang="en"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>{title} — Beat my track</title>
<meta property="og:title" content="{name} challenges you on {title}">
<meta property="og:description" content="{target} · Five laps · {vehicle}">
<style>body{{background:#080f16;color:#f1f4f3;font:20px system-ui;margin:0;min-height:100vh;display:grid;place-items:center}}
main{{background:#101e29;padding:40px;border-radius:12px;max-width:480px;margin:20px}}small{{color:#a4bac7}}h1{{margin:24px 0 8px}}
a{{display:block;padding:16px;background:#ffd348;color:#080f16;text-decoration:none;border-radius:5px;margin-top:24px}}
code{{font-size:18px;user-select:all}}.time{{font-size:48px;font-weight:700;margin:24px 0}}</style>
<main><small>BEAT MY TRACK · {state}</small><h1>{title}</h1><p>{name} challenges you</p><p class="time">{target}</p>
<p>Five laps · {vehicle}</p><a href="beatmytrack://challenge/{code}">Open Beat my track</a>
<p><small>Race → Challenges → Enter code</small><br><code>{code}</code></p></main></html>''',
                        headers={"Cache-Control": "no-store", "X-Robots-Tag": "noindex", "Referrer-Policy": "no-referrer"})
