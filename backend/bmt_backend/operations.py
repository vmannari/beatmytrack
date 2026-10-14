"""Credential-free competition health separate from API readiness."""
import copy
import shutil
import time
from contextlib import nullcontext
from pathlib import Path

from sqlalchemy import case, func, select
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .contracts import build_contract, current_manifest
from .publication_models import PublicationIntent
from .track_models import OperationState, Run, TrackValidation, now


def heartbeat(app, worker_id: str, *, coalesce=False, **details):
    # Routine job phases may arrive hundreds of times a second. Merge their
    # latest diagnostics locally; explicit lifecycle/build changes write now.
    with app.state.worker_heartbeat_lock:
        memory = app.state.worker_heartbeat_memory
        entry = memory.get(worker_id)
        pending = {**(entry["pending"] if entry else {}), **copy.deepcopy(details)}
        control = getattr(app.state, "worker_control", None)
        stopping = control and (control.requested_at is not None or control.stop.is_set())
        interval = min(1.0, app.state.settings.worker_stale_seconds / 4)
        force = (not coalesce or entry is None or "lifecycle" in pending or stopping
                 or "build" in details and details["build"] != entry["build"])
        if not force and time.monotonic() - entry["written"] < interval:
            entry["pending"] = pending
            memory.move_to_end(worker_id)
            return
        if entry is None:
            entry = memory[worker_id] = {"pending": {}, "written":float("-inf"), "build":None}
        entry["pending"] = dict(pending)  # Retain diagnostics if the database write fails.
    # PostgreSQL serializes a worker's row itself. Never hold an application
    # lock through pool/database waits: a shutdown heartbeat must get its own
    # chance to persist. SQLite tests share one connection and need serialization.
    write_lock = app.state.worker_heartbeat_lock if app.state.engine.dialect.name == "sqlite" else nullcontext()
    with write_lock:
        stored_build = _write_heartbeat(app, worker_id, pending)
    with app.state.worker_heartbeat_lock:
        entry = memory.setdefault(worker_id, {"pending": {}, "written":float("-inf"), "build":None})
        for key, value in pending.items():
            if entry["pending"].get(key) == value:
                entry["pending"].pop(key, None)
        entry.update(written=time.monotonic(), build=stored_build)
        memory.move_to_end(worker_id)
        while len(memory) > 64:
            memory.popitem(last=False)


def _write_heartbeat(app, worker_id, details):
    with app.state.session_factory() as session:
        insert = pg_insert if session.bind.dialect.name == "postgresql" else sqlite_insert
        session.execute(insert(OperationState).values(id="worker:" + worker_id, updated_at=now(), details={})
            .on_conflict_do_nothing(index_elements=[OperationState.id]))
        state = session.scalar(select(OperationState).where(OperationState.id == "worker:" + worker_id).with_for_update())
        previous = state.details or {}
        lifecycle = details.get("lifecycle", previous.get("lifecycle", "running"))
        control = getattr(app.state, "worker_control", None)
        if previous.get("lifecycle") == "stopped":
            lifecycle = "stopped"
        elif lifecycle != "stopped" and (previous.get("lifecycle") == "draining" or
                (control and (control.requested_at is not None or control.stop.is_set()))):
            lifecycle = "draining"
        state.updated_at, state.details = now(), {**previous, **details, "lifecycle": lifecycle}
        session.commit()
        return copy.deepcopy(state.details.get("build"))


def competition_health(app) -> dict:
    with app.state.session_factory() as session:
        current = now()
        depth, oldest = session.execute(select(func.count(), func.min(Run.created_at)).where(Run.status.in_(("queued", "verifying")))).one()
        recent_workers = session.scalars(select(OperationState).where(OperationState.id.startswith("worker:"), OperationState.updated_at >= current - app.state.settings.worker_stale_seconds)).all()
        workers = [w for w in recent_workers if w.details.get("lifecycle", "running") == "running"]
        verified = Run.status == "verified"
        completions, failed, rejected, latency_avg, latency_max = session.execute(select(
            func.coalesce(func.sum(case((verified, 1), else_=0)), 0),
            func.coalesce(func.sum(case((Run.status == "failed", 1), else_=0)), 0),
            func.coalesce(func.sum(case((Run.status == "rejected", 1), else_=0)), 0),
            func.avg(case((verified, Run.finished_at - Run.created_at))),
            func.max(case((verified, Run.finished_at - Run.created_at)))
        ).where(Run.finished_at >= current - 300)).one()
        failures = dict(session.execute(select(Run.failure_code, func.count()).where(Run.finished_at >= current - 300, Run.failure_code.is_not(None)).group_by(Run.failure_code)).all())
        arrivals = session.scalar(select(func.count()).select_from(Run).where(Run.created_at >= current - 300))
        validations, validation_oldest = session.execute(select(func.count(), func.min(TrackValidation.created_at)).where(TrackValidation.status.in_(("queued", "validating")))).one()
        publications, publication_oldest = session.execute(select(func.count(), func.min(PublicationIntent.created_at))
            .where(PublicationIntent.status.in_(("queued", "verifying")))).one()
        total_depth = depth + validations + publications
        guard = session.get(OperationState,"object-maintenance")
        oldest = min(value for value in (oldest, validation_oldest, publication_oldest) if value is not None) if total_depth else None
        marker = app.state.settings.backup_marker_path
        backup = {"status":"not_configured", "age_seconds":None}
        if marker:
            try:
                path = Path(marker)
                backup = {"status":"complete" if path.is_file() else "missing",
                          "age_seconds":max(0, current-int(path.stat().st_mtime)) if path.is_file() else None}
            except OSError:
                backup = {"status":"unreadable", "age_seconds":None}
        expected = {}
        supported = False
        if workers:
            try:
                manifest = app.state.verifier.manifest()
                expected = build_contract(manifest)
                supported = (current_manifest(manifest) == manifest
                             and all(value is not None for value in expected.values())
                             and expected["tick_rate"] == 120 and expected["laps"] == 5
                             and isinstance(expected["vehicles"], dict) and bool(expected["vehicles"]))
            except RuntimeError:
                pass
        available = [w for w in workers if supported and expected and w.details.get("build", {}) == expected]
        usable = bool(available)
        status = "ready" if usable else "api_contract_mismatch" if expected and not supported else "worker_build_mismatch" if expected else "verifier_unavailable" if workers else "worker_unavailable"
        return {"status":status, "expected_build":expected, "queue_depth": total_depth,
                "pending_races":depth,
                "queue_capacity": app.state.settings.max_queued_runs,
                "oldest_age_seconds": max(0, current - oldest) if oldest else 0,
                "active_workers": len(workers), "verified_last_5_minutes": completions,
                "available_workers": len(available),
                "draining_workers": sum(w.details.get("lifecycle") == "draining" for w in recent_workers),
                "stopped_workers": sum(w.details.get("lifecycle") == "stopped" for w in recent_workers),
                "verified_per_second_last_5_minutes": round(completions / 300, 4),
                "failed_last_5_minutes": failed, "rejected_last_5_minutes": rejected,
                "infrastructure_failure_rate_last_5_minutes": round(failed / (completions + failed), 4) if completions + failed else None,
                "completion_latency_seconds_last_5_minutes": {"mean": round(float(latency_avg), 3) if latency_avg is not None else None, "max": latency_max},
                "worker_queue_wait_seconds": {w.id.removeprefix("worker:"): w.details.get("last_queue_wait_seconds") for w in workers},
                "worker_verification_seconds": {w.id.removeprefix("worker:"): w.details.get("last_verification_seconds") for w in workers},
                "arrivals_last_5_minutes":arrivals, "pending_track_validations":validations, "pending_publications":publications,
                "worker_builds":[w.details.get("build", {}) for w in workers],
                "failures_last_5_minutes": failures,
                "estimated_wait_seconds": round(300 * depth / completions) if completions and not validations and not publications else None,
                "storage_backend":app.state.settings.object_backend,
                "storage_free_bytes": shutil.disk_usage(app.state.settings.object_dir).free if app.state.settings.object_backend=="local" else None,
                "object_gc_paused": bool(guard and guard.updated_at > current),
                "backup":backup}
