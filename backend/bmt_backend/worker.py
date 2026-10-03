"""Durable PostgreSQL verification worker with expiring leases and fenced finalization."""

from __future__ import annotations

import argparse
import logging
import time

from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert

from .contracts import build_contract, current_manifest
from .identity_models import Player
from .operations import heartbeat
from .queueing import record_claim
from .track_models import (
    Board,
    OperationState,
    PersonalBest,
    QueuePlayer,
    Run,
    Track,
    TrackVersion,
    new_id,
    now,
)

logger = logging.getLogger("bmt.worker")


class BuildMismatch(RuntimeError):
    """An existing ticket belongs to another verifier/rules build."""


def process_one(app) -> bool:
    """Claim at most one job; keep the expensive verifier outside DB transactions."""
    settings = app.state.settings
    worker_id = getattr(app.state, "worker_id", None)
    if worker_id is None:
        worker_id = app.state.worker_id = new_id()
    try:
        manifest = app.state.verifier.manifest()
        build = build_contract(manifest)
    except RuntimeError:
        build = {"status":"unavailable"}
    heartbeat(app, worker_id, phase="claiming", build=build)
    from .track_validation import process_one as validate_one
    # Alternate queues, keeping creator saves and race proofs from starving each other.
    app.state.prefer_track_validation = not getattr(app.state, "prefer_track_validation", False)
    if app.state.prefer_track_validation and validate_one(app):
        return True
    lease_seconds = settings.job_lease_seconds
    maximum_attempts = settings.max_job_attempts
    token = new_id()
    with app.state.session_factory() as session:
        queue = session.scalar(select(OperationState).where(OperationState.id == "queue").with_for_update())
        run = session.scalar(
            select(Run)
            .outerjoin(QueuePlayer, QueuePlayer.player_id == Run.player_id)
            .where(
                or_(
                    and_(Run.status == "queued", Run.lease_until <= now()),
                    and_(Run.status == "verifying", Run.lease_until <= now()),
                )
            )
            .order_by(func.coalesce(QueuePlayer.last_claim_at, 0), Run.created_at, Run.id)
            .with_for_update(skip_locked=True, of=Run)
            .limit(1)
        )
        if run is None:
            session.rollback()
            return validate_one(app)
        if run.attempts >= maximum_attempts:
            run.status, run.failure_code, run.finished_at = "failed", "verifier_unavailable", now()
            run.lease_token = None
            session.commit()
            return True
        run_id = run.id
        record_claim(session, queue, run.player_id)
        run.attempts += 1
        run.status, run.lease_token, run.lease_until = "verifying", token, now() + lease_seconds
        board = session.get(Board, run.board_id)
        version = session.get(TrackVersion, board.version_id)
        document_hash, replay_hash, vehicle_id = version.content_hash, run.replay_hash, board.vehicle_id
        creator_test = board.manifest.get("purpose") == "creator_test"
        expected_manifest = current_manifest(version.manifest)
        pinned_manifest = dict(board.manifest)
        session.commit()
    heartbeat(app, worker_id, phase="verifying")

    result, failure, rejected, permanent = None, None, False, False
    try:
        for field in ("engine_version", "verifier_version", "rules_key", "physics_version", "compiler_version", "track_schema", "replay_schema", "tick_rate"):
            if pinned_manifest.get(field) != expected_manifest.get(field): raise BuildMismatch
        vehicle = expected_manifest.get("vehicles", {}).get(vehicle_id, {})
        if (pinned_manifest.get("vehicle_id") != vehicle_id
            or pinned_manifest.get("handling_version") != vehicle.get("handling_version")
            or pinned_manifest.get("config_hash") != vehicle.get("config_hash")
            or pinned_manifest.get("track_content_hash") != expected_manifest.get("track_content_hash")
            or pinned_manifest.get("laps") != (1 if creator_test else expected_manifest.get("laps"))):
            raise BuildMismatch
        document = app.state.blobs.get_json(document_hash)
        replay = app.state.blobs.get_json(replay_hash)
        result = (app.state.verifier.verify_run(document, replay, vehicle_id, creator_test=True)
                  if creator_test else app.state.verifier.verify_run(document, replay, vehicle_id))
        ticks, lap_ticks = result.get("time_ticks"), result.get("lap_ticks")
        if result.get("manifest") != expected_manifest:
            raise RuntimeError("Verifier manifest differs from pinned track manifest")
        if (
            type(ticks) is not int
            or not 0 < ticks <= 216000
            or not isinstance(lap_ticks, list)
            or len(lap_ticks) != (1 if creator_test else expected_manifest["laps"])
            or any(type(value) is not int or value <= 0 for value in lap_ticks)
            or sum(lap_ticks) != ticks
        ):
            raise RuntimeError("Verifier returned malformed timing proof")
    except BuildMismatch:
        failure, permanent = "build_mismatch", True
        logger.error("verification_build_mismatch", extra={"run_id": run_id, "failure_code": failure})
    except ValueError:
        failure, rejected = "invalid_replay", True
    except Exception as exc:
        logger.exception("verification_infrastructure_error", extra={"run_id": run_id, "failure_code": "manifest_mismatch" if str(exc) == "Verifier manifest differs from pinned track manifest" else "verifier_unavailable"})
        failure = "verifier_unavailable"

    with app.state.session_factory() as session:
        run = session.scalar(select(Run).where(Run.id == run_id).with_for_update())
        if run.status != "verifying" or run.lease_token != token or run.lease_until <= now():
            logger.warning("verification_lease_lost", extra={"run_id": run_id})
            return True
        if failure:
            terminal = permanent or rejected or run.attempts >= maximum_attempts
            run.status = "rejected" if rejected else "failed" if terminal else "queued"
            run.failure_code, run.lease_token = failure, None
            run.lease_until = 0 if terminal else now() + min(60, 2**run.attempts)
            run.finished_at = now() if terminal else None
            session.commit()
            return True
        player = session.get(Player, run.player_id)
        if player.disabled:
            run.status, run.failure_code, run.finished_at, run.lease_token = (
                "rejected",
                "account_disabled",
                now(),
                None,
            )
            session.commit()
            return True
        run.status, run.time_ticks, run.lap_ticks = "verified", result["time_ticks"], result["lap_ticks"]
        run.finished_at, run.failure_code, run.lease_token, run.lease_until = now(), None, None, 0
        session.flush()
        if not creator_test:
            values = {
                "board_id": run.board_id,
                "player_id": run.player_id,
                "run_id": run.id,
                "time_ticks": run.time_ticks,
                "achieved_at": run.finished_at,
            }
            factory = pg_insert if session.bind.dialect.name == "postgresql" else sqlite_insert
            statement = factory(PersonalBest).values(**values)
            # A slower or tied result cannot replace the existing PB or its retained ghost.
            session.execute(
                statement.on_conflict_do_update(
                    index_elements=["board_id", "player_id"],
                    set_={key: values[key] for key in ("run_id", "time_ticks", "achieved_at")},
                    where=PersonalBest.time_ticks > values["time_ticks"],
                )
            )
        board = session.get(Board, run.board_id)
        version = session.get(TrackVersion, board.version_id)
        track = session.get(Track, version.track_id)
        if track.owner_id == run.player_id:
            session.execute(
                update(TrackVersion)
                .where(TrackVersion.id == version.id, TrackVersion.state == "draft")
                .values(state="tested", creator_test_run_id=run.id)
            )
        session.commit()
        logger.info("verification_complete", extra={"run_id": run_id, "time_ticks": result["time_ticks"]})
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true", help="Process at most one currently eligible job")
    args = parser.parse_args()
    from .app import create_app

    app = create_app()
    while True:
        worked = process_one(app)
        if args.once:
            return
        if not worked:
            time.sleep(1)


if __name__ == "__main__":
    main()
