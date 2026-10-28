"""Durable development-only test-record reset and all-track canonical reseeding."""
from __future__ import annotations

import logging
import uuid
from collections import Counter, defaultdict
from pathlib import Path
from types import SimpleNamespace

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, select, update
from sqlalchemy.orm import aliased

from .background_work import BackgroundControl, BackgroundYielded
from .contracts import build_contract, current_manifest
from .identity_models import Player
from .rivalry_models import RivalryBest, RivalryGroup
from .test_driver_generator import CONTROLLER_VERSION
from .test_driver_models import TestDriverProfile
from .test_drivers import Fleet, Operator, create_fleet
from .test_population import require_enabled
from .track_models import (
    Board,
    LapBestState,
    OperationState,
    PersonalBest,
    Run,
    Track,
    TrackVersion,
    digest,
    now,
)
from .tracks import DB, track_payload

router = APIRouter(include_in_schema=False)
logger = logging.getLogger("bmt.test_population_batch")
ACTIVE = "test-population-active"


def catalog(app, session, vehicle):
    active = app.state.verifier.manifest()
    if vehicle not in active["vehicles"]:
        raise HTTPException(422, "Unknown vehicle")
    newer = aliased(TrackVersion)
    versions = session.execute(select(TrackVersion, Track, Player.display_name).select_from(TrackVersion)
        .join(Track, Track.id == TrackVersion.track_id).join(Player, Player.id == Track.owner_id)
        .where(TrackVersion.state == "published", Track.hidden.is_(False), Track.archived.is_(False),
               Player.disabled.is_(False), ~select(newer.id).where(newer.track_id == Track.id,
               newer.state == "published", newer.number > TrackVersion.number).exists())
        .order_by(TrackVersion.id).limit(1000)).all()
    entries = []
    for version, track, name in versions:
        if build_contract(current_manifest(version.manifest)) != build_contract(active):
            continue
        entries.append(track_payload(version, track, name, app.state.settings.public_base_url))
    return active, entries


def record_rows(session, track_ids, *, test):
    rows = session.execute(select(PersonalBest, Board, Player.is_test_driver).select_from(PersonalBest).join(Board).join(
        TrackVersion, TrackVersion.id == Board.version_id).join(Player, Player.id == PersonalBest.player_id)
        .where(TrackVersion.track_id.in_(track_ids))).all()
    return [pb for pb, board, synthetic in rows
            if (bool(board.manifest.get("test_population")) or synthetic) == test]


def preview(app, session, vehicle):
    active, entries = catalog(app, session, vehicle)
    tracks = sorted({e["track_id"] for e in entries})
    tests = record_rows(session, tracks, test=True)
    real = record_rows(session, tracks, test=False)
    ids = sorted((p.board_id, p.player_id, p.run_id, p.time_ticks) for p in tests)
    protected = digest(sorted((p.board_id, p.player_id, p.run_id, p.time_ticks) for p in real))
    return {"vehicle_id": vehicle, "manifest": active, "tracks": entries,
            "test_records": len(tests), "protected_real_records": len(real),
            "protected_real_digest": protected,
            "inventory_digest": digest({"versions": [e["version_id"] for e in entries],
                                        "test_records": ids, "build": build_contract(active)})}


@router.get("/dev/test-drivers/batches/preview")
def preview_route(request: Request, session: DB, _operator: Operator, vehicle_id: str = "compact"):
    return preview(request.app, session, vehicle_id)


class BatchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    seed: int = Field(ge=0, le=2147483647)
    count: int = Field(default=100, ge=1, le=200)
    vehicle_id: str = "compact"
    generation: int = Field(default=0, ge=0, le=1000)
    clear_test_records: bool = True
    inventory_digest: str = Field(min_length=64, max_length=64)


class LocalClaim(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    runner_id: str = Field(pattern=r"^[a-f0-9-]{36}$")


class LocalOutcome(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    lease_token: str = Field(pattern=r"^[a-f0-9-]{36}$")
    run_id: str | None = Field(default=None, min_length=36, max_length=36)
    failure: str | None = Field(default=None, pattern=r"^(timeout|not_finished|temporary_failure)$")


@router.get("/dev/test-drivers/local-rivalries")
def local_rivalries(session: DB, _operator: Operator):
    rows = session.scalars(select(RivalryGroup).where(RivalryGroup.test_population.is_(True),
        RivalryGroup.ends_at > now(), RivalryGroup.tracks[0]["automatic_test_drivers"].as_boolean().is_(True))
        .order_by(RivalryGroup.created_at).limit(100)).all()
    return {"groups": [{"group_id": g.id, "vehicle_id": g.vehicle_id, "ends_at": g.ends_at} for g in rows],
        "execution": "local_on_demand"}


@router.get("/dev/test-drivers/local-rivalries/{group_id}/plan")
def local_rivalry_plan(group_id: str, request: Request, session: DB, _operator: Operator):
    from .automatic_test_drivers import plan_for
    group = session.get(RivalryGroup, group_id)
    if (not group or not group.test_population or group.ends_at <= now() or not group.tracks
            or not group.tracks[0].get("automatic_test_drivers")):
        raise HTTPException(404, "Active artificial rivalry not found")
    plan = plan_for(request.app, group_id, SimpleNamespace(url=request.app.state.settings.public_base_url))
    if plan is None:
        raise HTTPException(409, "Artificial rivalry build is unavailable")
    return plan


@router.post("/dev/test-drivers/batches")
def create_batch(payload: BatchRequest, request: Request, session: DB, _operator: Operator):
    require_enabled(request)
    identity = f"bmt-test-batch/{payload.seed}/{payload.vehicle_id}"
    if payload.generation:
        identity += f"/generation/{payload.generation}"
    batch_id = str(uuid.uuid5(uuid.NAMESPACE_URL, identity))
    key = "test-pop-batch:" + batch_id
    old = session.get(OperationState, key)
    body = payload.model_dump()
    if old:
        if {"generation": 0, **old.details["request"]} != body:
            raise HTTPException(409, "BATCH_PARAMETERS_CHANGED")
        return batch_view(session, batch_id)
    guard = session.scalar(select(OperationState).where(OperationState.id == ACTIVE).with_for_update())
    if guard and guard.details.get("status") == "running" and batch_view(session, guard.details["batch_id"])["complete"]:
        guard.details = {**guard.details, "status": "complete"}
    if guard and guard.details.get("status") == "running":
        raise HTTPException(409, "A test population batch is already running")
    inventory = preview(request.app, session, payload.vehicle_id)
    if inventory["inventory_digest"] != payload.inventory_digest:
        raise HTTPException(409, "RECORD_INVENTORY_CHANGED")
    if not inventory["tracks"]:
        raise HTTPException(409, "No compatible published tracks")
    # Existing identity creation is idempotent; never converts a real player.
    fleet = create_fleet(Fleet(seed=payload.seed, count=payload.count), request, session, None)
    guard = session.scalar(select(OperationState).where(OperationState.id == ACTIVE).with_for_update())
    if guard and guard.details.get("status") == "running":
        raise HTTPException(409, "A test population batch is already running")
    inventory_after = preview(request.app, session, payload.vehicle_id)
    if inventory_after["inventory_digest"] != payload.inventory_digest:
        raise HTTPException(409, "RECORD_INVENTORY_CHANGED")
    track_ids = sorted({e["track_id"] for e in inventory["tracks"]})
    cleared = 0
    if payload.clear_test_records:
        # Lock/fence runs before PB/board writes, matching verifier finalization
        # order. Otherwise reset can hold a PB while waiting for its board and
        # the verifier can hold that board while waiting for the same PB.
        boards = session.scalars(select(Board).join(TrackVersion).where(
            TrackVersion.track_id.in_(track_ids))).all()
        test_ids = [b.id for b in boards if b.manifest.get("test_population")]
        if test_ids:
            session.execute(update(Run).where(Run.board_id.in_(test_ids),
                Run.status.in_(("queued", "verifying"))).values(status="failed", failure_code="test_records_reset",
                finished_at=now(), lease_token=None, lease_until=0))
        # A finalization may have committed while the fence waited. Preserve the
        # existing inventory contract rather than clearing an unreviewed PB.
        if preview(request.app, session, payload.vehicle_id)["inventory_digest"] != payload.inventory_digest:
            session.rollback()
            raise HTTPException(409, "RECORD_INVENTORY_CHANGED")
        # Artificial private lap writes share-lock this state before publishing.
        # Reset takes the exclusive lock before touching PB/board projections.
        session.scalars(select(LapBestState).where(LapBestState.board_id.in_(test_ids))
            .order_by(LapBestState.board_id).with_for_update()).all()
        affected = record_rows(session, track_ids, test=True)
        run_ids = [p.run_id for p in affected]
        for p in affected:
            session.delete(p)
        if run_ids:
            session.execute(delete(RivalryBest).where(RivalryBest.run_id.in_(run_ids)))
        cleared = len(affected)
        session.flush()
        if preview(request.app, session, payload.vehicle_id)["protected_real_digest"] != inventory["protected_real_digest"]:
            session.rollback()
            raise HTTPException(409, "REAL_RECORD_PROTECTION_FAILED")
    details = {"batch_id": batch_id, "request": body, "status": "running", "fleet": fleet["fleet"],
               "controller_version": CONTROLLER_VERSION,
               "vehicle_id": payload.vehicle_id, "manifest": inventory["manifest"],
               "tracks": inventory["tracks"], "player_ids": [p["player_id"] for p in fleet["profiles"]],
               "count": payload.count, "jobs": payload.count*len(inventory["tracks"]),
               "cleared_test_records": cleared, "protected_real_records": inventory["protected_real_records"],
               "protected_real_digest": inventory["protected_real_digest"], "created_at": now()}
    session.add(OperationState(id=key, updated_at=now(), details=details))
    for ordinal, profile in enumerate(fleet["profiles"]):
        for slot, entry in enumerate(inventory["tracks"]):
            job_id = digest({"batch": batch_id, "player": profile["player_id"], "version": entry["version_id"]})
            job = {"id": job_id, "batch_id": batch_id, "player_id": profile["player_id"],
                   "subject": profile["subject"], "slot": slot, "ordinal": ordinal,
                   "version_id": entry["version_id"], "content_hash": entry["content_hash"],
                   "attempt": 0, "status": "waiting", "due": now(), "lease_until": 0}
            session.add(OperationState(id="test-pop-job:"+job_id, updated_at=now(), details=job))
    if guard is None:
        guard = OperationState(id=ACTIVE, updated_at=now(), details={})
        session.add(guard)
    guard.details = {"batch_id": batch_id, "status": "running"}
    session.commit()
    return batch_view(session, batch_id)


def batch_jobs(session, batch_id):
    return session.scalars(select(OperationState).where(OperationState.id.startswith("test-pop-job:"),
        OperationState.details["batch_id"].as_string() == batch_id)).all()


def batch_view(session, batch_id):
    batch = session.get(OperationState, "test-pop-batch:"+batch_id)
    if batch is None:
        raise HTTPException(404, "Test population batch not found")
    data = batch.details
    jobs = batch_jobs(session, batch_id)
    # Completion is derived from ordinary server-verified runs; no always-on
    # artificial-generation process is needed to update progress.
    states = dict(session.execute(select(Run.id, Run.status).join(OperationState,
        OperationState.details["run_id"].as_string() == Run.id).where(
        OperationState.id.startswith("test-pop-job:"), OperationState.details["batch_id"].as_string() == batch_id)).all())
    def status(job):
        actual = states.get(job.details.get("run_id"))
        return actual if job.details["status"] == "submitted" and actual in ("verified", "skipped", "rejected", "failed") else job.details["status"]
    counts = Counter(status(j) for j in jobs)
    complete = bool(jobs) and counts.get("verified", 0) + counts.get("skipped", 0) == data["jobs"]
    verified_by_slot, completed_by_slot = defaultdict(set), defaultdict(set)
    for job in jobs:
        state = status(job)
        if state == "verified":
            verified_by_slot[job.details["slot"]].add(job.details["player_id"])
        if state in ("verified", "skipped"):
            completed_by_slot[job.details["slot"]].add(job.details["player_id"])
    per_track = []
    for slot, entry in enumerate(data["tracks"]):
        per_track.append({"name": entry["name"], "version_id": entry["version_id"],
                          "verified_players": len(verified_by_slot[slot]), "completed_players": len(completed_by_slot[slot]), "target": data["count"]})
    return {"batch_id": batch_id, "status": "complete" if complete else data["status"], "test_population": True,
            "execution": "local_on_demand",
            "controller_version": data.get("controller_version", "profiled-trajectory-5"),
            "vehicle_id": data["vehicle_id"], "driver_count": data["count"], "track_count": len(per_track),
            "jobs": dict(counts), "expected_jobs": data["jobs"], "tracks": per_track,
            "cleared_test_records": data["cleared_test_records"],
            "protected_real_records": data["protected_real_records"],
            "complete": complete}


@router.get("/dev/test-drivers/batches/active")
def active_batch(session: DB, _operator: Operator):
    guard = session.get(OperationState, ACTIVE)
    return {"batch": batch_view(session, guard.details["batch_id"]) if guard and guard.details.get("batch_id") else None}


@router.get("/dev/test-drivers/batches/{batch_id}")
def get_batch(batch_id: str, session: DB, _operator: Operator):
    return batch_view(session, batch_id)


@router.post("/dev/test-drivers/batches/{batch_id}/claim")
def claim_local(batch_id: str, payload: LocalClaim, request: Request, session: DB, _operator: Operator):
    """Lease one artificial job; this endpoint never starts an engine."""
    guard = session.scalar(select(OperationState).where(OperationState.id == ACTIVE).with_for_update())
    batch = session.scalar(select(OperationState).where(OperationState.id == "test-pop-batch:"+batch_id).with_for_update())
    if batch is None:
        raise HTTPException(404, "Test population batch not found")
    if not guard or guard.details.get("batch_id") != batch_id or guard.details.get("status") != "running":
        if batch.details.get("status") == "complete":
            return {"work": None, "batch": batch_view(session, batch_id)}
        raise HTTPException(409, "ARTIFICIAL_BATCH_NOT_ACTIVE")
    data = batch.details
    if build_contract(data["manifest"]) != build_contract(request.app.state.verifier.manifest()):
        raise HTTPException(409, "BATCH_BUILD_CHANGED")
    at = now()
    # Normal server verification can finish after a local pass exits. Reconcile
    # only bounded submitted rows on the next explicit claim, never in a daemon.
    completed = session.execute(select(OperationState, Run).join(Run,
        OperationState.details["run_id"].as_string() == Run.id).where(
        OperationState.id.startswith("test-pop-job:"), OperationState.details["batch_id"].as_string() == batch_id,
        OperationState.details["status"].as_string() == "submitted",
        Run.status.in_(("verified", "skipped", "rejected", "failed"))).limit(200)).all()
    for item, run in completed:
        value = {**item.details, "status": run.status, "time_ticks": run.time_ticks, "failure_code": run.failure_code}
        if run.status in ("rejected", "failed") and value["attempt"] < 4:
            value.update(status="waiting", attempt=value["attempt"]+1, due=at+10, lease_until=0)
            value.pop("run_id", None)
        item.details = value; item.updated_at = at
    session.flush()
    query = select(OperationState).where(OperationState.id.startswith("test-pop-job:"),
        OperationState.details["batch_id"].as_string() == batch_id)
    own = session.scalar(query.where(OperationState.details["status"].as_string() == "generating",
        OperationState.details["runner_id"].as_string() == payload.runner_id,
        OperationState.details["lease_until"].as_integer() > at).limit(1).with_for_update())
    row = own or session.scalar(query.where(
        OperationState.details["status"].as_string().in_(("waiting", "generating")),
        OperationState.details["due"].as_integer() <= at,
        OperationState.details["lease_until"].as_integer() <= at)
        .order_by(OperationState.updated_at, OperationState.id).limit(1).with_for_update(skip_locked=True))
    if row is None:
        view = batch_view(session, batch_id)
        if view["complete"]:
            batch.details = {**batch.details, "status": "complete", "completed_at": at}
            guard.details = {**guard.details, "status": "complete"}
        session.commit()
        return {"work": None, "batch": view}
    job = dict(row.details)
    profile = session.get(TestDriverProfile, job["player_id"])
    player = session.get(Player, job["player_id"])
    if not profile or not player or not player.is_test_driver or player.disabled or player.deleted_at is not None:
        raise HTTPException(409, "ARTIFICIAL_PROFILE_UNAVAILABLE")
    if own is None:
        job.update(status="generating", runner_id=payload.runner_id, lease_token=str(uuid.uuid4()), lease_until=at+600)
        row.details = job; row.updated_at = at
    session.commit()
    return {"work": {"job": job, "traits": profile.traits, "vehicle_id": data["vehicle_id"], "manifest": data["manifest"]}}


@router.post("/dev/test-drivers/batches/{batch_id}/jobs/{job_id}/complete")
def complete_local(batch_id: str, job_id: str, payload: LocalOutcome, session: DB, _operator: Operator):
    if (payload.run_id is None) == (payload.failure is None):
        raise HTTPException(422, "Provide one verified-upload receipt or failure category")
    guard = session.scalar(select(OperationState).where(OperationState.id == ACTIVE).with_for_update())
    if not guard or guard.details.get("batch_id") != batch_id:
        raise HTTPException(409, "ARTIFICIAL_BATCH_NOT_ACTIVE")
    row = session.scalar(select(OperationState).where(OperationState.id == "test-pop-job:"+job_id).with_for_update())
    if row is None or row.details.get("batch_id") != batch_id:
        raise HTTPException(404, "Artificial job not found")
    job = dict(row.details)
    # A retry of an acknowledged completion is harmless. An expired or replaced
    # lease cannot overwrite a newer worker, even with a previously valid token.
    if job.get("lease_token") != payload.lease_token:
        raise HTTPException(409, "ARTIFICIAL_LEASE_REPLACED")
    if job.get("status") in ("submitted", "verified", "skipped", "rejected", "failed") and payload.run_id == job.get("run_id"):
        return {"status": job["status"]}
    if job.get("status") != "generating" or job.get("lease_until", 0) <= now():
        raise HTTPException(409, "ARTIFICIAL_LEASE_EXPIRED")
    if payload.run_id:
        run = session.get(Run, payload.run_id)
        board = session.get(Board, run.board_id) if run else None
        player = session.get(Player, job["player_id"])
        if (not run or not board or not player or not player.is_test_driver or run.player_id != job["player_id"]
                or board.version_id != job["version_id"] or not board.manifest.get("test_population")):
            raise HTTPException(409, "ARTIFICIAL_UPLOAD_RECEIPT_MISMATCH")
        job.update(status="submitted", run_id=run.id, lease_until=0)
    else:
        attempt = job["attempt"] + 1
        job.update(status="waiting" if attempt <= 4 else "uncompleted", attempt=attempt,
            due=now()+10*attempt, lease_until=0, failure_code="local_"+payload.failure)
    row.details = job; row.updated_at = now(); session.commit()
    return {"status": job["status"]}


def drive_idle(app, *, generation_control=None):
    """One genuine drive from a durable batch; ordinary proofs remain first."""
    settings = app.state.settings
    if not (settings.environment == "development" and settings.test_drivers_enabled and settings.dev_auth_enabled):
        return False
    from .test_driver_generator import DriverDidNotFinish, GenerationTimedOut, generate
    from .test_population_tool import API, recording
    from .worker_lifecycle import stopping
    if not settings.godot_bin or stopping(app):
        return False
    with app.state.session_factory() as session:
        guard = session.get(OperationState, ACTIVE)
        if not guard or guard.details.get("status") != "running":
            return False
        batch = session.get(OperationState, "test-pop-batch:"+guard.details["batch_id"])
        data = batch.details
        if build_contract(data["manifest"]) != build_contract(app.state.verifier.manifest()):
            return False
        jobs = batch_jobs(session, data["batch_id"])
        changed = False
        for row in jobs:
            job = dict(row.details)
            if job["status"] == "submitted":
                run = session.get(Run, job["run_id"])
                if run and run.status in ("verified", "skipped", "rejected", "failed"):
                    job.update(status=run.status, time_ticks=run.time_ticks, failure_code=run.failure_code)
                    if run.status not in ("verified", "skipped") and job["attempt"] < 4:
                        job.update(status="waiting", attempt=job["attempt"]+1, due=now()+10)
                    row.details = job; row.updated_at = now(); changed = True
        if changed:
            session.commit()
        if all(j.details["status"] in ("verified", "skipped") for j in jobs):
            batch.details = {**data, "status": "complete", "completed_at": now()}
            guard.details = {**guard.details, "status": "complete"}
            session.commit()
            return True
        row = session.scalar(select(OperationState).where(OperationState.id.startswith("test-pop-job:"),
            OperationState.details["batch_id"].as_string() == data["batch_id"],
            OperationState.details["status"].as_string().in_(("waiting", "generating")),
            OperationState.details["due"].as_integer() <= now(),
            OperationState.details["lease_until"].as_integer() <= now())
            .order_by(OperationState.details["ordinal"].as_integer(), OperationState.details["slot"].as_integer())
            .with_for_update(skip_locked=True).limit(1))
        if row is None:
            return changed
        job = dict(row.details)
        token = str(uuid.uuid4())
        row.details = {**job, "status": "generating", "lease_token": token, "lease_until": now()+600}
        profile = session.get(TestDriverProfile, job["player_id"])
        traits = dict(profile.traits)
        row_id = row.id
        session.commit()
    api = getattr(app.state, "batch_driver_api", None)
    if api is None:
        api = app.state.batch_driver_api = API(settings.test_driver_api_url or settings.public_base_url,
                                             settings.dev_auth_key, internal=True, stop_event=generation_control)
    api.stop_event = generation_control
    folder = Path(settings.object_dir).parent / "test-population-batches" / data["batch_id"]
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / "plan.json"
    plan = {"vehicle_id": data["vehicle_id"], "manifest": data["manifest"], "pace_scales": {}}
    job["id"] = digest({"job": job["id"], "attempt": job["attempt"]})
    try:
        recovered = api.call("GET", "/dev/test-drivers/uploads/"+job["id"]+"-upload",
                             subject=job["subject"], operator=True)
        if recovered.get("run"):
            result = recovered["run"]
        else:
            def generator(*args, **kwargs):
                return generate(*args, **kwargs, stop_event=generation_control or BackgroundControl(app))
            replay = recording(api, plan, job, {"traits": traits}, settings, path, generator=generator)
            ticket = api.call("POST", "/run-tickets", {"version_id": job["version_id"],
                "vehicle_id": data["vehicle_id"], "test_population": True}, job["subject"], job["id"]+"-ticket")
            result = api.call("POST", "/runs", {"ticket_id": ticket["ticket_id"], "replay": replay["replay"]},
                              job["subject"], job["id"]+"-upload")
        outcome = {"status": "submitted", "run_id": result["run_id"], "lease_until": 0}
    except BackgroundYielded:
        outcome = {"status": "waiting", "due": now()+3, "lease_until": 0}
    except (DriverDidNotFinish, GenerationTimedOut) as error:
        outcome = {"status": "waiting" if job["attempt"] < 4 else "uncompleted",
                   "attempt": job["attempt"]+1, "due": now()+10, "lease_until": 0,
                   "failure_code": str(error)[:500]}
    except (RuntimeError, OSError):
        logger.exception("test_population_batch_attempt_failed", extra={"batch_id": data["batch_id"]})
        outcome = {"status": "waiting", "due": now()+30, "lease_until": 0}
    with app.state.session_factory() as session:
        row = session.scalar(select(OperationState).where(OperationState.id == row_id).with_for_update())
        if row.details.get("lease_token") != token:
            return False
        row.details = {**row.details, **outcome}; row.updated_at = now()
        session.commit()
    return True
