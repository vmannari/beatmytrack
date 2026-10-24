"""Bounded published World/Country/Friends reads and audited owner corrections."""
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, HTTPException, Query, Request, Response
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import select, tuple_

from .admin import Access
from .admin_models import AdminAudit
from .community import blocked_ids
from .cursors import decode_cursor, encode_cursor
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .runs import BoardDB
from .track_models import digest, now
from .tracks import DB, Auth
from .world_ranking_models import (
    Circuit,
    RankingAward,
    RankingBranch,
    RankingCareer,
    RankingControl,
    RankingCorrection,
    RankingPlayer,
    RankingSnapshot,
    RankingStanding,
)
from .world_ranking_rules import CAR, POLICY, WEEK, breakdown, season_start

router = APIRouter(route_class=ParsedJSONRoute, tags=["world ranking"])


def _snapshot(db, requested=None):
    control = db.get(RankingControl, 1)
    if control is None or control.published_id is None:
        return control, None
    identity = requested or control.published_id
    if identity not in (control.published_id, control.previous_id):
        raise HTTPException(409, "RANKING_SNAPSHOT_EXPIRED")
    return control, db.get(RankingSnapshot, identity)


def _metadata(db, control, snapshot, launch=0):
    result = {"policy": POLICY, "car": CAR, "launch_week": control.launch_week if control else launch,
              "state": "published" if snapshot else "not_started", "best_results": 12,
              "rolling_weeks": 26, "items": [], "next_cursor": ""}
    if snapshot:
        start = season_start(snapshot.week_start, control.launch_week)
        result.update(snapshot_id=snapshot.id, week_start=snapshot.week_start,
            published_at=snapshot.published_at, field_size=snapshot.field_size, ranked_count=snapshot.ranked_count,
            season_start=start, season_end=start+13*WEEK,
            season_qualifying_weeks=snapshot.season_qualifying_weeks)
    return result


def _render(rows, blocked, rank_field):
    result = []
    for standing, player in rows:
        hidden = player.id in blocked or player.disabled or player.deleted_at is not None or player.is_test_driver
        result.append({"player_id": "" if hidden else player.id,
            "name": "Blocked player" if player.id in blocked else "Removed account" if hidden else player.display_name,
            "country": "" if hidden else standing.country, "rank": getattr(standing, rank_field),
            "world_rank": standing.world_rank, "points": standing.total,
            "season_points": standing.season_points, "season_rank": standing.season_rank})
    return result


def _response(request, payload):
    etag = '"'+digest(payload)+'"'
    if request.headers.get("if-none-match") == etag:
        return Response(status_code=304, headers={"ETag": etag, "Cache-Control": "private, no-cache"})
    from fastapi.responses import JSONResponse
    return JSONResponse(payload, headers={"ETag": etag, "Cache-Control": "private, no-cache"})


@router.get("/v1/ranking")
def board(request: Request, session: BoardDB, player: Auth,
          scope: Literal["world", "country", "friends", "season"] = "world",
          country: str = Query(default="", max_length=2), cursor: str = Query(default="", max_length=400),
          around: bool = False):
    parsed = decode_cursor(cursor) if cursor else {}
    if parsed and (set(parsed) != {"snapshot", "scope", "country", "viewer", "rank", "key"}
        or parsed["scope"] != scope or parsed["viewer"] != player.id
        or any(type(parsed[k]) is not int or parsed[k] < 0 for k in ("snapshot", "rank", "key"))):
        raise HTTPException(422, "INVALID_CURSOR")
    control, snapshot = _snapshot(session, parsed.get("snapshot"))
    payload = _metadata(session, control, snapshot, request.app.state.settings.world_ranking_launch_week)
    payload["scope"] = scope
    if snapshot is None:
        return _response(request, payload)
    key = session.scalar(select(RankingPlayer.key).where(RankingPlayer.player_id == player.id))
    own = session.get(RankingStanding, (snapshot.id, key)) if key is not None else None
    blocked = set(session.scalars(blocked_ids(session, player.id)))
    field = {"country": "country_rank", "season": "season_rank"}.get(scope, "world_rank")
    ranking = getattr(RankingStanding, field)
    query = select(RankingStanding, Player).join(RankingPlayer,
        RankingPlayer.key == RankingStanding.player_key).join(Player, Player.id == RankingPlayer.player_id)
    query = query.where(RankingStanding.snapshot_id == snapshot.id, ranking.is_not(None))
    if scope == "country":
        chosen = country or (own.country if own else player.country_code)
        if len(chosen) != 2 or not chosen.isascii() or not chosen.isalpha():
            payload["state"] = "country_required"
            return _response(request, payload)
        query = query.where(RankingStanding.country == chosen.upper())
        payload["country"] = chosen.upper()
        country = chosen.upper()
        if own is not None and own.country != country:
            own = None  # An explicit other-country view starts at its top.
    if parsed and parsed["country"] != country:
        raise HTTPException(422, "INVALID_CURSOR")
    if scope == "friends":
        from .news import friend_ids
        roster = [player.id, *friend_ids(session, player.id)]
        query = query.where(RankingPlayer.player_id.in_(roster), Player.disabled.is_(False),
            Player.deleted_at.is_(None), ~Player.id.in_(blocked))
        all_rows = list(session.execute(query.order_by(ranking, RankingStanding.player_key)))
        rendered = _render(all_rows, blocked, field)
        previous, position = None, 0
        for index, row in enumerate(rendered):
            if row["world_rank"] != previous:
                position = index+1
            previous, row["rank"] = row["world_rank"], position
        offset = parsed.get("key", 0)
        if around and own:
            index = next((i for i, r in enumerate(rendered) if r["player_id"] == player.id), 0)
            offset = max(0, index-4)
        payload["items"] = rendered[offset:offset+(9 if around else 50)]
        if not around and offset+50 < len(rendered):
            payload["next_cursor"] = encode_cursor({"snapshot": snapshot.id, "scope": scope,
                "country": country, "viewer": player.id, "rank": 0, "key": offset+50})
    else:
        ordering = tuple_(ranking, RankingStanding.player_key)
        if around and own and getattr(own, field) is not None:
            anchor = (getattr(own, field), key)
            before = list(session.execute(query.where(ordering < anchor).order_by(ranking.desc(), RankingStanding.player_key.desc()).limit(4)))
            after = list(session.execute(query.where(ordering >= anchor).order_by(ranking, RankingStanding.player_key).limit(5)))
            rows = [*reversed(before), *after]
        else:
            if parsed:
                query = query.where(ordering > (parsed["rank"], parsed["key"]))
            rows = list(session.execute(query.order_by(ranking, RankingStanding.player_key).limit(51)))
            if len(rows) > 50:
                last = rows[49][0]
                payload["next_cursor"] = encode_cursor({"snapshot": snapshot.id, "scope": scope,
                    "country": country, "viewer": player.id, "rank": getattr(last, field), "key": last.player_key})
                rows = rows[:50]
        payload["items"] = _render(rows, blocked, field)
    return _response(request, payload)


def profile_payload(db, player_id, viewer, launch=0):
    control, snapshot = _snapshot(db)
    result = _metadata(db, control, snapshot, launch)
    result.pop("items")
    result.update(world_rank=None, country_rank=None, points=0, movement=None, results=[],
                  career={}, points_at_risk=0, earned=0, net_change=0, season_points=0, season_rank=None)
    if snapshot is None:
        return result
    target = db.get(Player, player_id)
    if target is None or target.disabled or target.deleted_at is not None or target.is_test_driver:
        raise HTTPException(404, "Player unavailable")
    if player_id in set(db.scalars(blocked_ids(db, viewer))):
        raise HTTPException(403, "PLAYER_BLOCKED")
    key = db.scalar(select(RankingPlayer.key).where(RankingPlayer.player_id == player_id))
    if key is None:
        result["state"] = "unranked"
        return result
    standing = db.get(RankingStanding, (snapshot.id, key))
    if standing:
        result.update(world_rank=standing.world_rank, country_rank=standing.country_rank, country=standing.country,
            points=standing.total, season_points=standing.season_points, season_rank=standing.season_rank)
    else:
        result["state"] = "unranked"
    records = list(db.execute(select(Circuit.week_start, RankingAward.points, RankingAward.weekly_place)
        .join(RankingAward, RankingAward.circuit_id == Circuit.id).where(RankingAward.branch_id == snapshot.branch_id,
            RankingAward.player_key == key, Circuit.week_start.between(snapshot.week_start-25*WEEK, snapshot.week_start))
        .order_by(Circuit.week_start.desc()).limit(26)))
    view = breakdown(records, snapshot.week_start)
    result.update(results=view["results"], points_at_risk=view["points_at_risk"])
    current = next((r for r in records if r[0] == snapshot.week_start), None)
    result["earned"] = current[1] if current else 0
    previous = db.get(RankingStanding, (control.previous_id, key)) if control.previous_id else None
    result["net_change"] = result["points"]-(previous.total if previous else 0)
    if previous and standing:
        result["movement"] = previous.world_rank-standing.world_rank
    career = db.scalar(select(RankingCareer).where(RankingCareer.branch_id == snapshot.branch_id,
        RankingCareer.player_key == key, RankingCareer.generation <= snapshot.id)
        .order_by(RankingCareer.generation.desc()).limit(1))
    if career:
        result["career"] = {name: getattr(career, name) for name in
            ("peak_rank", "peak_week", "peak_field", "weeks_top100", "weeks_no1", "victories", "season_titles")}
    return result


@router.get("/v1/ranking/me")
def own_profile(request: Request, session: BoardDB, player: Auth):
    return _response(request, profile_payload(session, player.id, player.id, request.app.state.settings.world_ranking_launch_week))


@router.get("/v1/ranking/players/{player_id}")
def public_profile(player_id: UUID, request: Request, session: BoardDB, player: Auth):
    return _response(request, profile_payload(session, str(player_id), player.id, request.app.state.settings.world_ranking_launch_week))


class Correct(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    command_id: str = Field(min_length=36, max_length=36)
    expected_snapshot: int = Field(ge=0)
    circuit_id: int = Field(ge=1)
    player_id: str = Field(default="", max_length=36)
    void_week: bool = False
    reason: str = Field(min_length=8, max_length=500)


@router.post("/v1/admin/ranking/corrections")
def correct(body: Correct, request: Request, role: Access, session: DB):
    if role != "owner":
        raise HTTPException(403, "OWNER_REQUIRED")
    try:
        UUID(body.command_id)
    except ValueError:
        raise HTTPException(422, "INVALID_COMMAND_ID") from None
    if bool(body.player_id) == body.void_week or len(body.reason.strip()) < 8:
        raise HTTPException(422, "CHOOSE_PLAYER_OR_VOID_WEEK")
    hashed = digest(body.model_dump())
    prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == body.command_id))
    if prior:
        if prior.request_hash != hashed:
            raise HTTPException(409, "COMMAND_ID_REUSED")
        return prior.after
    control = session.scalar(select(RankingControl).where(RankingControl.id == 1).with_for_update())
    # Serialize retries with the same lock as commands and publication. Another
    # request may have committed the command while this one waited for the lock.
    prior = session.scalar(select(AdminAudit).where(AdminAudit.command_id == body.command_id))
    if prior:
        if prior.request_hash != hashed:
            raise HTTPException(409, "COMMAND_ID_REUSED")
        return prior.after
    if control is None or (control.published_id or 0) != body.expected_snapshot:
        raise HTTPException(409, "RANKING_CHANGED_REFRESH_REQUIRED")
    branch = session.scalar(select(RankingBranch).where(RankingBranch.id == control.running_branch).with_for_update())
    if branch.phase != "idle" or branch.mode == "rebuild":
        raise HTTPException(409, "RANKING_SETTLEMENT_BUSY_RETRY")
    circuit = session.get(Circuit, body.circuit_id)
    current = session.get(RankingSnapshot, control.published_id) if control.published_id else None
    if circuit is None or circuit.week_start+WEEK > now():
        raise HTTPException(422, "CIRCUIT_NOT_CLOSED")
    unpublished_void = body.void_week and circuit.original_snapshot is None
    if not unpublished_void and (current is None or circuit.week_start > current.week_start or circuit.original_snapshot is None):
        raise HTTPException(422, "CIRCUIT_NOT_PUBLISHED")
    key = session.scalar(select(RankingPlayer.key).where(RankingPlayer.player_id == body.player_id)) if body.player_id else 0
    if key is None:
        raise HTTPException(404, "Player not found")
    session.add(RankingCorrection(command_id=body.command_id, circuit_id=circuit.id, player_key=key,
        actor=role, reason=body.reason.strip(), created_at=now()))
    if unpublished_void:
        after = {"state": "void_queued", "branch_id": branch.id, "previous_snapshot": control.published_id}
    else:
        rebuild = RankingBranch(mode="rebuild", next_week=control.launch_week, through_week=current.week_start,
            reason=body.reason.strip())
        session.add(rebuild)
        session.flush()
        control.running_branch = rebuild.id
        after = {"state": "rebuilding", "branch_id": rebuild.id, "previous_snapshot": current.id}
    session.add(AdminAudit(command_id=body.command_id, actor=role, action="world_ranking_correction",
        entity_id=str(circuit.id), reason=body.reason.strip(), before={"snapshot": control.published_id},
        after=after, request_hash=hashed, request_id=request.state.request_id))
    session.commit()
    return after


@router.get("/v1/admin/ranking/status")
def status(request: Request, role: Access, session: DB):
    control = session.get(RankingControl, 1)
    if control is None:
        return {"state": "not_started", "launch_week": request.app.state.settings.world_ranking_launch_week}
    branch = session.get(RankingBranch, control.running_branch)
    return {"published_snapshot": control.published_id, "launch_week": control.launch_week,
        "circuit_id": session.scalar(select(Circuit.id).where(Circuit.week_start == branch.next_week)),
        "phase": branch.phase, "mode": branch.mode, "week_start": branch.next_week,
        "processed_through": branch.cursor, "retrying": bool(branch.failure),
        "error_kind": branch.failure.split(":", 1)[0] if branch.failure else ""}
