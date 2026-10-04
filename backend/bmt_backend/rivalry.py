"""Weekly championships over immutable tracks and server-verified races."""
from __future__ import annotations

import secrets
import statistics
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Query, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import func, or_, select, update
from sqlalchemy.exc import IntegrityError

from .contracts import build_contract, current_manifest
from .identity_models import Player
from .middleware import ParsedJSONRoute
from .rivalry_models import RivalryBest, RivalryGroup, RivalryMember, RivalryTicket
from .runs import PINNED_FIELDS, _ticket_payload, board_manifest
from .track_models import (
    Board,
    OperationState,
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
from .tracks import DB, Auth, Key, track_payload
from .test_population import check_scope, contract_scope

router = APIRouter(route_class=ParsedJSONRoute, tags=["weekly rivalry"])
TRACK_COUNT = 5
GROUP_CAPACITY = 20
POINTS = (30, 26, 23, 20, 18, 16, 14, 12, 10, 8, 6, 4, 2, 1, 1, 1, 1, 1, 1, 1)
random = secrets.SystemRandom()


class Join(BaseModel):
    model_config = ConfigDict(extra="forbid")
    vehicle_id: str = Field(min_length=1, max_length=80)
    test_population: bool = False


class Race(BaseModel):
    model_config = ConfigDict(extra="forbid")
    slot: int = Field(strict=True, ge=0, lt=TRACK_COUNT)


def week_window(timestamp: int) -> tuple[int, int, int, int]:
    day = timestamp // 86400
    start = (day - (day + 3) % 7) * 86400  # Monday 00:00 UTC.
    iso = datetime.fromtimestamp(start, timezone.utc).isocalendar()
    return start, start + 7 * 86400, iso.year, iso.week


def active_contract(request, vehicle):
    try:
        active = request.app.state.verifier.manifest()
    except RuntimeError:
        raise HTTPException(503, "Race verifier temporarily unavailable") from None
    config = active.get("vehicles", {}).get(vehicle)
    if not config:
        raise HTTPException(422, "Vehicle is not allowed by the server manifest")
    return active, digest({**build_contract(active), "vehicles": {vehicle: config}, "vehicle_id": vehicle})


def eligible_versions(session, active, vehicle):
    """Strict >4.0 AND >100 distinct verified finishers; official bypass only."""
    finishers = (select(Board.version_id.label("version"), func.count(func.distinct(PersonalBest.player_id)).label("drivers"))
                 .join(PersonalBest, PersonalBest.board_id == Board.id)
                 .join(Player, Player.id == PersonalBest.player_id)
                 .where(Player.disabled.is_(False), Player.is_test_driver.is_(False),
                        Board.manifest["purpose"].as_string().is_(None),
                        Board.manifest["test_population"].as_boolean().is_not(True))
                 .group_by(Board.version_id).subquery())
    latest = (select(TrackVersion.track_id.label("track"), func.max(TrackVersion.number).label("number"))
              .where(TrackVersion.state == "published").group_by(TrackVersion.track_id).subquery())
    candidates = session.scalars(select(TrackVersion).join(Track).join(Player, Player.id == Track.owner_id)
        .join(latest, (latest.c.track == Track.id) & (latest.c.number == TrackVersion.number))
        .outerjoin(finishers, finishers.c.version == TrackVersion.id)
        .where(TrackVersion.state == "published", Track.hidden.is_(False), Player.disabled.is_(False),
               or_(Track.official.is_(True), (TrackVersion.rating_count > 0)
                   & (TrackVersion.rating_sum > 4 * TrackVersion.rating_count) & (finishers.c.drivers > 100)))
        .order_by(func.random()).limit(1000)).all()
    return [version for version in candidates
            if all(current_manifest(version.manifest).get(field) == active.get(field) for field in PINNED_FIELDS)
            and version.manifest.get("vehicles", {}).get(vehicle) == active.get("vehicles", {}).get(vehicle)]


def skill_score(session, player_id, vehicle, active, timestamp, test_population=False):
    """Median percentage beaten on up to 20 recent comparable verified boards."""
    own = session.execute(select(PersonalBest, Board).join(Board)
        .where(PersonalBest.player_id == player_id, Board.vehicle_id == vehicle,
               PersonalBest.achieved_at >= timestamp - 90 * 86400)
        .order_by(PersonalBest.achieved_at.desc(), Board.id).limit(20)).all()
    scores = []
    config = active["vehicles"][vehicle]
    for best, board in own:
        if (bool(board.manifest.get("test_population")) != test_population
                or board.manifest.get("purpose") or board.manifest.get("rules_key") != active["rules_key"]
                or board.manifest.get("config_hash") != config["config_hash"]
                or board.manifest.get("physics_version") != active["physics_version"]):
            continue
        times = (select(PersonalBest.time_ticks).join(Player)
                 .where(PersonalBest.board_id == board.id, Player.disabled.is_(False)).subquery())
        if not test_population:
            times = (select(PersonalBest.time_ticks).join(Player).where(PersonalBest.board_id == board.id,
                     Player.disabled.is_(False), Player.is_test_driver.is_(False)).subquery())
        total = session.scalar(select(func.count()).select_from(times))
        if total < 5:
            continue
        slower = session.scalar(select(func.count()).select_from(times).where(times.c.time_ticks > best.time_ticks))
        tied = session.scalar(select(func.count()).select_from(times).where(times.c.time_ticks == best.time_ticks))
        scores.append(round(1000 * (slower + (tied - 1) / 2) / (total - 1)))
    return round(statistics.median(scores)) if len(scores) >= 3 else None


def require_member(session, group_id, player_id, request=None):
    member = session.get(RivalryMember, (group_id, player_id))
    group = session.get(RivalryGroup, group_id)
    if member is None or group is None:
        raise HTTPException(404, "Rivalry not found")
    if request is not None:
        check_scope(request, group.test_population, session.get(Player, player_id))
    return group, member


def rankings(rows, key, reverse=False):
    rows.sort(key=lambda row: (row[key] is None, -row[key] if reverse and row[key] is not None else row[key] or 0, row["id"]))
    previous, rank = None, None
    for position, row in enumerate(rows):
        if row[key] is None:
            row["rank"] = None
            continue
        if rank is None or row[key] != previous:
            rank = position + 1
        row["rank"], previous = rank, row[key]
    return rows


def standings_data(session, group):
    players = session.execute(select(Player.id, Player.display_name, Player.is_test_driver).join(RivalryMember)
        .where(RivalryMember.group_id == group.id, Player.disabled.is_(False)).order_by(Player.id)).all()
    bests = {(best.slot, best.player_id): best for best in session.scalars(select(RivalryBest).where(RivalryBest.group_id == group.id))}
    totals = {pid: {"id": pid, "name": name, "is_test_driver": synthetic, "points": 0, "completed": 0} for pid, name, synthetic in players}
    tracks = []
    for slot, entry in enumerate(group.tracks):
        rows = []
        for pid, name, synthetic in players:
            best = bests.get((slot, pid))
            rows.append({"id": pid, "name": name, "is_test_driver": synthetic, "ticks": best.time_ticks if best else None,
                         "ms": round(best.time_ticks * 1000 / entry["tick_rate"]) if best else None,
                         "run_id": best.run_id if best else None})
        rankings(rows, "ticks")
        for row in rows:
            row["points"] = POINTS[row["rank"] - 1] if row["rank"] else 0
            totals[row["id"]]["points"] += row["points"]
            totals[row["id"]]["completed"] += int(row["ticks"] is not None)
        tracks.append(rows)
    overall = rankings(list(totals.values()), "points", True)
    for row in overall:
        if row["completed"] == 0:
            row["rank"] = None
    return tracks, overall


def snapshot(session, group, player_id, timestamp=None):
    # Join and verification writers share this lock, so every view has one
    # coherent membership/points snapshot even with concurrent PostgreSQL jobs.
    group = session.scalar(select(RivalryGroup).where(RivalryGroup.id == group.id)
                           .with_for_update().execution_options(populate_existing=True))
    timestamp = now() if timestamp is None else timestamp
    tracks, overall = standings_data(session, group)
    pending = session.scalar(select(func.count()).select_from(Run).join(RivalryTicket, RivalryTicket.ticket_id == Run.ticket_id)
        .where(RivalryTicket.group_id == group.id, Run.status.in_(("queued", "verifying"))))
    state = "active" if timestamp < group.ends_at else "settling" if pending else "complete"
    iso = datetime.fromtimestamp(group.week_start, timezone.utc).isocalendar()
    result = {"group_id": group.id, "state": state, "week": iso.week, "year": iso.year,
              "ends_at": group.ends_at, "server_now": timestamp, "remaining_seconds": max(0, group.ends_at - timestamp),
              "vehicle_id": group.vehicle_id, "placement": group.skill_band == -1, "driver_count": len(overall),
              "test_population": group.test_population,
              "group_forming": len(overall) < 10, "standings": overall, "self_id": player_id, "tracks": [],
              "points_policy": list(POINTS), "pending_runs": pending}
    for slot, pinned in enumerate(group.tracks):
        version = session.get(TrackVersion, pinned["version_id"])
        track = session.get(Track, version.track_id)
        owner = session.get(Player, track.owner_id)
        result["tracks"].append({"slot": slot, "entry": pinned["entry"], "board_id": pinned["board_id"],
                                 "available": version.state == "published" and not track.hidden and not owner.disabled,
                                 "entries": tracks[slot]})
    return result


@router.get("/rivalry/current")
def current(request: Request, session: DB, player: Auth, vehicle_id: str = Query(min_length=1, max_length=80), test_population: bool = False):
    check_scope(request, test_population, player)
    active, contract = active_contract(request, vehicle_id)
    contract = contract_scope(contract, test_population)
    start, end, year, week = week_window(now())
    member = session.scalar(select(RivalryMember).where(RivalryMember.player_id == player.id,
        RivalryMember.week_start == start, RivalryMember.contract_key == contract))
    if member:
        return snapshot(session, session.get(RivalryGroup, member.group_id), player.id)
    previous = session.scalar(select(RivalryMember).join(RivalryGroup)
        .where(RivalryMember.player_id == player.id, RivalryGroup.vehicle_id == vehicle_id,
               RivalryGroup.test_population.is_(test_population),
               RivalryMember.week_start < start, RivalryMember.acknowledged.is_(False))
        .order_by(RivalryMember.week_start.desc()).limit(1))
    if previous:
        return snapshot(session, session.get(RivalryGroup, previous.group_id), player.id)
    return {"state": "not_joined", "test_population": test_population, "week": week, "year": year, "ends_at": end, "server_now": now(),
            "eligible_track_count": len(eligible_versions(session, active, vehicle_id)), "required_track_count": TRACK_COUNT}


@router.post("/rivalry/join")
def join(payload: Join, request: Request, session: DB, player: Auth, key: Key):
    check_scope(request, payload.test_population, player)
    body = payload.model_dump()
    old = replay_response(session, player.id, "rivalry_join", key, body)
    if old is not None:
        return old
    if player.needs_username:
        raise HTTPException(409, "USERNAME_REQUIRED")
    active, contract = active_contract(request, payload.vehicle_id)
    contract = contract_scope(contract, payload.test_population)
    timestamp = now()
    start, end, _, _ = week_window(timestamp)
    member = session.scalar(select(RivalryMember).where(RivalryMember.player_id == player.id,
        RivalryMember.week_start == start, RivalryMember.contract_key == contract))
    if member:
        return commit_response(session, player.id, "rivalry_join", key, body,
                               snapshot(session, session.get(RivalryGroup, member.group_id), player.id, timestamp))
    session.scalar(select(Player).where(Player.id == player.id).with_for_update())
    member = session.scalar(select(RivalryMember).where(RivalryMember.player_id == player.id,
        RivalryMember.week_start == start, RivalryMember.contract_key == contract))
    if member:
        return commit_response(session, player.id, "rivalry_join", key, body,
                               snapshot(session, session.get(RivalryGroup, member.group_id), player.id, timestamp))
    skill = skill_score(session, player.id, payload.vehicle_id, active, timestamp, payload.test_population)
    band = min(9, skill // 100) if skill is not None else -1
    lock_id = digest({"week": start, "contract": contract, "band": band})
    if session.get(OperationState, lock_id) is None:
        try:
            with session.begin_nested():
                session.add(OperationState(id=lock_id))
                session.flush()
        except IntegrityError:
            pass
    session.scalar(select(OperationState).where(OperationState.id == lock_id).with_for_update())
    groups = session.scalars(select(RivalryGroup).where(RivalryGroup.week_start == start,
        RivalryGroup.contract_key == contract, RivalryGroup.skill_band == band,
        RivalryGroup.member_count < GROUP_CAPACITY).order_by(RivalryGroup.created_at).limit(100)).all()
    random.shuffle(groups)
    group = None
    for candidate in groups:
        candidate = session.scalar(select(RivalryGroup).where(RivalryGroup.id == candidate.id).with_for_update())
        # The conditional increment also protects the capacity on SQLite,
        # whose SELECT FOR UPDATE has no effect. A failed reservation retries
        # another open group; membership and reservation commit together.
        reserved = session.execute(update(RivalryGroup).where(RivalryGroup.id == candidate.id,
            RivalryGroup.member_count < GROUP_CAPACITY).values(member_count=RivalryGroup.member_count+1)).rowcount
        if reserved:
            group = candidate
            break
    if group is None:
        eligible = eligible_versions(session, active, payload.vehicle_id)
        if len(eligible) < TRACK_COUNT:
            raise HTTPException(409, "NOT_ENOUGH_ELIGIBLE_TRACKS")
        slots = []
        for version in random.sample(eligible, TRACK_COUNT):
            pinned = board_manifest(version, payload.vehicle_id)
            if payload.test_population:
                pinned = {**pinned, "test_population": True}
            board_id = digest({"version_id": version.id, **pinned})
            if session.get(Board, board_id) is None:
                try:
                    with session.begin_nested():
                        session.add(Board(id=board_id, version_id=version.id, vehicle_id=payload.vehicle_id, manifest=pinned))
                        session.flush()
                except IntegrityError:
                    pass
            track = session.get(Track, version.track_id)
            owner = session.get(Player, track.owner_id)
            entry = track_payload(version, track, owner.display_name, request.app.state.settings.public_base_url)
            entry.pop("manifest", None)
            slots.append({"version_id": version.id, "board_id": board_id, "tick_rate": pinned["tick_rate"], "entry": entry})
        group = RivalryGroup(week_start=start, ends_at=end, vehicle_id=payload.vehicle_id,
                             test_population=payload.test_population,
                             contract_key=contract, skill_band=band, tracks=slots, member_count=1)
        session.add(group)
        session.flush()
    session.add(RivalryMember(group_id=group.id, player_id=player.id, week_start=start, contract_key=contract, skill=skill))
    session.flush()
    return commit_response(session, player.id, "rivalry_join", key, body, snapshot(session, group, player.id, timestamp))


@router.get("/rivalry/{group_id}")
def view(group_id: str, request: Request, session: DB, player: Auth):
    group, _ = require_member(session, group_id, player.id, request)
    return snapshot(session, group, player.id)


@router.post("/rivalry/{group_id}/tickets", status_code=201)
def ticket(group_id: str, payload: Race, request: Request, session: DB, player: Auth, key: Key):
    body, scope = payload.model_dump(), "rivalry_ticket:" + group_id
    old = replay_response(session, player.id, scope, key, body)
    if old is not None:
        return old
    group, _ = require_member(session, group_id, player.id, request)
    if now() >= group.ends_at:
        raise HTTPException(410, "RIVALRY_WEEK_ENDED")
    _active, contract = active_contract(request, group.vehicle_id)
    contract = contract_scope(contract, group.test_population)
    if contract != group.contract_key:
        raise HTTPException(409, "RIVALRY_BUILD_CHANGED")
    pinned = group.tracks[payload.slot]
    version = session.get(TrackVersion, pinned["version_id"])
    track = session.get(Track, version.track_id)
    if version.state != "published" or track.hidden or session.get(Player, track.owner_id).disabled:
        raise HTTPException(404, "Rivalry track unavailable")
    board = session.get(Board, pinned["board_id"])
    race_ticket = RunTicket(player_id=player.id, board_id=board.id, expires_at=min(now() + 7200, group.ends_at))
    session.add(race_ticket)
    session.flush()
    session.add(RivalryTicket(ticket_id=race_ticket.id, group_id=group.id, slot=payload.slot))
    return commit_response(session, player.id, scope, key, body,
                           {**_ticket_payload(race_ticket, board), "rivalry_group": group.id, "rivalry_slot": payload.slot})


def accept_verified(session, run):
    """Called within fenced worker finalization; retries/slower runs mint no points."""
    binding = session.get(RivalryTicket, run.ticket_id)
    if binding is None or binding.outcome is not None:
        return
    group = session.scalar(select(RivalryGroup).where(RivalryGroup.id == binding.group_id).with_for_update())
    if not group.week_start <= run.created_at < group.ends_at:
        return
    before_tracks, before_overall = standings_data(session, group)
    prior = next(row for row in before_tracks[binding.slot] if row["id"] == run.player_id)
    best = session.get(RivalryBest, (group.id, run.player_id, binding.slot))
    improved = best is None or run.time_ticks < best.time_ticks
    if improved:
        if best is None:
            best = RivalryBest(group_id=group.id, player_id=run.player_id, slot=binding.slot)
            session.add(best)
        best.run_id, best.time_ticks, best.achieved_at = run.id, run.time_ticks, now()
        session.flush()
    after_tracks, after_overall = standings_data(session, group)
    after = next(row for row in after_tracks[binding.slot] if row["id"] == run.player_id)
    beaten = [row for row in before_tracks[binding.slot] if row["id"] != run.player_id and row["ticks"] is not None
              and run.time_ticks < row["ticks"] and (prior["ticks"] is None or row["ticks"] < prior["ticks"])] if improved else []
    binding.outcome = {"improved": improved, "before": prior, "after": after,
                       "points_delta": after["points"] - prior["points"], "beaten": beaten,
                       "ms": round(run.time_ticks * 1000 / group.tracks[binding.slot]["tick_rate"]),
                       "overall_before": next(row for row in before_overall if row["id"] == run.player_id),
                       "overall_after": next(row for row in after_overall if row["id"] == run.player_id)}


@router.get("/rivalry/tickets/{ticket_id}/result")
def result(ticket_id: str, request: Request, session: DB, player: Auth):
    own = session.get(RunTicket, ticket_id)
    binding = session.get(RivalryTicket, ticket_id)
    if own is None or binding is None or own.player_id != player.id:
        raise HTTPException(404, "Rivalry result not found")
    require_member(session, binding.group_id, player.id, request)
    run = session.scalar(select(Run).where(Run.ticket_id == ticket_id))
    status = run.status if run else "verified" if binding.outcome else "expired" if now() >= own.expires_at else "upload_pending"
    return {"status": status, "failure_code": run.failure_code if run else None,
            "outcome": binding.outcome, "slot": binding.slot}


@router.post("/rivalry/{group_id}/continue")
def acknowledge(group_id: str, request: Request, session: DB, player: Auth, key: Key):
    scope = "rivalry_continue:" + group_id
    old = replay_response(session, player.id, scope, key, {})
    if old is not None:
        return old
    group, member = require_member(session, group_id, player.id, request)
    if snapshot(session, group, player.id)["state"] != "complete":
        raise HTTPException(409, "RIVALRY_NOT_COMPLETE")
    member.acknowledged = True
    return commit_response(session, player.id, scope, key, {}, {"acknowledged": True})


@router.get("/rivalry/{group_id}/tracks/{slot}/ghosts/{driver_id}")
def ghost(group_id: str, slot: int, driver_id: str, request: Request, session: DB, player: Auth):
    require_member(session, group_id, player.id, request)
    if session.get(RivalryMember, (group_id, driver_id)) is None or session.get(Player, driver_id).disabled:
        raise HTTPException(404, "Rival ghost unavailable")
    best = session.get(RivalryBest, (group_id, driver_id, slot))
    run = session.get(Run, best.run_id) if best else None
    if run is None or not run.ghost_hash:
        raise HTTPException(404, "Rival ghost unavailable")
    return {"run_id": run.id, "recording": request.app.state.blobs.get_json(run.ghost_hash)}
