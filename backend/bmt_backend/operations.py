"""Credential-free competition health separate from API readiness."""
import shutil
from pathlib import Path

from sqlalchemy import func, select

from .contracts import build_contract, current_manifest
from .track_models import OperationState, Run, TrackValidation, now


def heartbeat(app, worker_id: str, **details):
    with app.state.session_factory() as session:
        state = session.get(OperationState, "worker:" + worker_id)
        if state is None:
            state = OperationState(id="worker:" + worker_id)
            session.add(state)
        state.updated_at, state.details = now(), {**(state.details or {}), **details}
        session.commit()


def competition_health(app) -> dict:
    with app.state.session_factory() as session:
        current = now()
        depth, oldest = session.execute(select(func.count(), func.min(Run.created_at)).where(Run.status.in_(("queued", "verifying")))).one()
        workers = session.scalars(select(OperationState).where(OperationState.id.startswith("worker:"), OperationState.updated_at >= current - app.state.settings.worker_stale_seconds)).all()
        completions = session.scalar(select(func.count()).select_from(Run).where(Run.finished_at >= current - 300, Run.status == "verified"))
        failures = dict(session.execute(select(Run.failure_code, func.count()).where(Run.finished_at >= current - 300, Run.failure_code.is_not(None)).group_by(Run.failure_code)).all())
        arrivals = session.scalar(select(func.count()).select_from(Run).where(Run.created_at >= current - 300))
        validations, validation_oldest = session.execute(select(func.count(), func.min(TrackValidation.created_at)).where(TrackValidation.status.in_(("queued", "validating")))).one()
        total_depth = depth + validations
        oldest = min(value for value in (oldest, validation_oldest) if value is not None) if total_depth else None
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
        usable = supported and bool(expected) and any(w.details.get("build", {}) == expected for w in workers)
        status = "ready" if usable else "api_contract_mismatch" if expected and not supported else "worker_build_mismatch" if expected else "verifier_unavailable" if workers else "worker_unavailable"
        return {"status":status, "expected_build":expected, "queue_depth": total_depth,
                "pending_races":depth,
                "queue_capacity": app.state.settings.max_queued_runs,
                "oldest_age_seconds": max(0, current - oldest) if oldest else 0,
                "active_workers": len(workers), "verified_last_5_minutes": completions,
                "arrivals_last_5_minutes":arrivals, "pending_track_validations":validations,
                "worker_builds":[w.details.get("build", {}) for w in workers],
                "failures_last_5_minutes": failures,
                "estimated_wait_seconds": round(300 * depth / completions) if completions and not validations else None,
                "storage_free_bytes": shutil.disk_usage(app.state.settings.object_dir).free,
                "backup":backup}
