"""Durable development-only test-record reset and all-track canonical reseeding."""
from __future__ import annotations

import logging
import uuid
from collections import Counter
from pathlib import Path

from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy import delete, select, update
from sqlalchemy.orm import aliased

from .contracts import build_contract, current_manifest
from .identity_models import Player
from .rivalry_models import RivalryBest
from .test_driver_models import TestDriverProfile
from .test_drivers import Fleet, Operator, create_fleet
from .test_population import require_enabled
from .track_models import Board, OperationState, PersonalBest, Run, Track, TrackVersion, digest, now
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
    clear_test_records: bool = True
    inventory_digest: str = Field(min_length=64, max_length=64)


@router.post("/dev/test-drivers/batches")
def create_batch(payload: BatchRequest, request: Request, session: DB, _operator: Operator):
    require_enabled(request)
    batch_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"bmt-test-batch/{payload.seed}/{payload.vehicle_id}"))
    key = "test-pop-batch:" + batch_id
    old = session.get(OperationState, key)
    body = payload.model_dump()
    if old:
        if old.details["request"] != body:
            raise HTTPException(409, "BATCH_PARAMETERS_CHANGED")
        return batch_view(session, batch_id)
    guard = session.scalar(select(OperationState).where(OperationState.id == ACTIVE).with_for_update())
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
        affected = record_rows(session, track_ids, test=True)
        run_ids = [p.run_id for p in affected]
        for p in affected:
            session.delete(p)
        if run_ids:
            session.execute(delete(RivalryBest).where(RivalryBest.run_id.in_(run_ids)))
        # Fence old queued test submissions so they cannot restore reset PBs.
        boards = session.scalars(select(Board).join(TrackVersion).where(
            TrackVersion.track_id.in_(track_ids))).all()
        test_ids = [b.id for b in boards if b.manifest.get("test_population")]
        if test_ids:
            session.execute(update(Run).where(Run.board_id.in_(test_ids),
                Run.status.in_(("queued", "verifying"))).values(status="failed", failure_code="test_records_reset",
                finished_at=now(), lease_token=None, lease_until=0))
        cleared = len(affected)
        session.flush()
        if preview(request.app, session, payload.vehicle_id)["protected_real_digest"] != inventory["protected_real_digest"]:
            session.rollback()
            raise HTTPException(409, "REAL_RECORD_PROTECTION_FAILED")
    details = {"batch_id": batch_id, "request": body, "status": "running", "fleet": fleet["fleet"],
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
    counts = Counter(j.details["status"] for j in jobs)
    per_track = []
    for slot, entry in enumerate(data["tracks"]):
        verified = {j.details["player_id"] for j in jobs if j.details["slot"] == slot and j.details["status"] == "verified"}
        per_track.append({"name": entry["name"], "version_id": entry["version_id"],
                          "verified_players": len(verified), "target": data["count"]})
    return {"batch_id": batch_id, "status": data["status"], "test_population": True,
            "vehicle_id": data["vehicle_id"], "driver_count": data["count"], "track_count": len(per_track),
            "jobs": dict(counts), "expected_jobs": data["jobs"], "tracks": per_track,
            "cleared_test_records": data["cleared_test_records"],
            "protected_real_records": data["protected_real_records"],
            "complete": bool(jobs) and counts.get("verified", 0) == data["jobs"]}


@router.get("/dev/test-drivers/batches/{batch_id}")
def get_batch(batch_id: str, session: DB, _operator: Operator):
    return batch_view(session, batch_id)


def drive_idle(app):
    """One genuine drive from a durable batch; ordinary proofs remain first."""
    settings = app.state.settings
    if not (settings.environment == "development" and settings.test_drivers_enabled and settings.dev_auth_enabled):
        return False
    from .test_driver_generator import DriverDidNotFinish, generate
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
                if run and run.status in ("verified", "rejected", "failed"):
                    job.update(status=run.status, time_ticks=run.time_ticks, failure_code=run.failure_code)
                    if run.status != "verified" and job["attempt"] < 4:
                        job.update(status="waiting", attempt=job["attempt"]+1, due=now()+10)
                    row.details = job; row.updated_at = now(); changed = True
        if changed:
            session.commit()
        if all(j.details["status"] == "verified" for j in jobs):
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
                                             settings.dev_auth_key, internal=True)
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
            control = getattr(app.state, "worker_control", None)
            def generator(*args, **kwargs):
                return generate(*args, **kwargs, stop_event=control.abort if control else None)
            replay = recording(api, plan, job, {"traits": traits}, settings, path, generator=generator)
            ticket = api.call("POST", "/run-tickets", {"version_id": job["version_id"],
                "vehicle_id": data["vehicle_id"], "test_population": True}, job["subject"], job["id"]+"-ticket")
            result = api.call("POST", "/runs", {"ticket_id": ticket["ticket_id"], "replay": replay["replay"]},
                              job["subject"], job["id"]+"-upload")
        outcome = {"status": "submitted", "run_id": result["run_id"], "lease_until": 0}
    except DriverDidNotFinish as error:
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
