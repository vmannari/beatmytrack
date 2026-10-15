"""Durable PostgreSQL verification worker with expiring leases and fenced finalization."""

from __future__ import annotations

import argparse
import logging
import time

from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.dialects.sqlite import insert as sqlite_insert
from sqlalchemy.exc import SQLAlchemyError

from .contracts import BUILD_FIELDS, build_contract
from .identity_models import Player
from .job_contracts import pinned_filter, worker_filter
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
from .verifier import VerificationError, VerifierStopping
from .worker_lifecycle import aborting, run_worker, stopping

logger = logging.getLogger("bmt.worker")


class BuildMismatch(RuntimeError):
    """An existing ticket belongs to another verifier/rules build."""


def process_one(app, *, refresh_histograms=False) -> bool:
    """Claim at most one job; keep the expensive verifier outside DB transactions."""
    if stopping(app):
        return False
    pending = getattr(app.state, "pending_finalization", None)
    if pending is not None and finalize(app, *pending):
        return True
    settings = app.state.settings
    worker_id = getattr(app.state, "worker_id", None)
    if worker_id is None:
        worker_id = app.state.worker_id = new_id()
    try:
        manifest = app.state.verifier.manifest()
        build = build_contract(manifest)
    except RuntimeError:
        build = {"status":"unavailable"}
        heartbeat(app, worker_id, phase="unavailable", build=build)
        return False
    if stopping(app):
        return False
    heartbeat(app, worker_id, phase="claiming", build=build, coalesce=True)
    # Foreground races take priority. An explicit publication is verified before
    # artificial races/background generation; editor saves never enter a queue.
    from .publications import process_one as publish_one
    from .track_validation import process_one as validate_one
    with app.state.session_factory() as session:
        foreground = session.scalar(select(Run.id).join(Board, Board.id == Run.board_id)
            .join(Player, Player.id == Run.player_id).where(Player.is_test_driver.is_(False),
                pinned_filter(Board.manifest, manifest), Run.status.in_(("queued", "verifying")),
                Run.lease_until <= now()).limit(1))
    if foreground is None and publish_one(app):
        return True
    lease_seconds = settings.job_lease_seconds
    maximum_attempts = settings.max_job_attempts
    token = new_id()
    with app.state.session_factory() as session:
        run = session.scalar(
            select(Run)
            .join(Board, Board.id == Run.board_id)
            .join(Player, Player.id == Run.player_id)
            .outerjoin(QueuePlayer, QueuePlayer.player_id == Run.player_id)
            .where(
                pinned_filter(Board.manifest, manifest),
                or_(
                    and_(Run.status == "queued", Run.lease_until <= now()),
                    and_(Run.status == "verifying", Run.lease_until <= now()),
                )
            )
            .order_by(Player.is_test_driver, func.coalesce(QueuePlayer.last_claim_at, 0), Run.created_at, Run.id)
            .with_for_update(skip_locked=True, of=Run)
            .limit(1)
        )
        if run is None:
            session.rollback()
            if expire_unserviceable(app):
                return True
            if publish_one(app):
                return True
            if validate_one(app):
                return True
            if refresh_histograms:
                from .lap_bests import backfill_one
                if backfill_one(app.state.session_factory)["worked"]:
                    return True
                from .histogram_snapshots import refresh_one as refresh_histogram
                if refresh_histogram(app):
                    return True
            from .test_population_batch import drive_idle as drive_batch
            if drive_batch(app):
                return True
            from .automatic_test_drivers import drive_idle
            return drive_idle(app)
        if stopping(app):
            return False
        if run.attempts >= maximum_attempts:
            run.status, run.failure_code, run.finished_at = "failed", "verifier_unavailable", now()
            run.lease_token = None
            session.commit()
            return True
        run_id = run.id
        record_claim(session, None, run.player_id)
        run.attempts += 1
        run.status, run.lease_token, run.lease_until = "verifying", token, now() + lease_seconds
        board = session.get(Board, run.board_id)
        version = session.get(TrackVersion, board.version_id)
        document_hash, replay_hash, vehicle_id = version.content_hash, run.replay_hash, board.vehicle_id
        redacted_track_hash = version.redacted_track_hash
        creator_test = board.manifest.get("purpose") == "creator_test"
        # Optional client-recorded ghosts accompany trajectory evidence.
        from .rivalry_models import RivalryTicket
        needs_ghost = not creator_test and (not session.get(Player, run.player_id).is_test_driver
                                            or session.get(RivalryTicket, run.ticket_id) is not None)
        # Keep immutable geometry/hash, use the exact claimed cohort's actual build.
        expected_manifest = {**version.manifest, **{field: manifest[field] for field in BUILD_FIELDS}}
        pinned_manifest = dict(board.manifest)
        if stopping(app):
            session.rollback()
            return False
        session.commit()
    queue_wait = max(0, now() - run.created_at)
    heartbeat(app, worker_id, phase="verifying", last_queue_wait_seconds=queue_wait, coalesce=True)

    result, failure, rejected, permanent, ghost_hash = None, None, False, False, None
    started = time.monotonic()
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
        from .verifier import GodotVerifier
        options = {"creator_test": True} if creator_test else {}
        if isinstance(app.state.verifier, GodotVerifier):
            options["capture_ghost"] = needs_ghost
            from .trajectory_verifier import prepared_geometry
            options["geometry"] = prepared_geometry(app,document_hash,document)
        result = app.state.verifier.verify_run(document, replay, vehicle_id, **options)
        ticks, lap_ticks = result.get("time_ticks"), result.get("lap_ticks")
        if redacted_track_hash and result.get("manifest", {}).get("track_content_hash") == redacted_track_hash:
            result["manifest"] = {**result["manifest"], "track_content_hash": expected_manifest["track_content_hash"]}
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
        if needs_ghost and result.get("ghost"):
            from .verifier import validate_ghost
            try:
                validate_ghost(result["ghost"], ticks)
            except (RuntimeError, ValueError, OverflowError):
                result.pop("ghost",None)  # Bad presentation cannot invalidate a proper race.
        if needs_ghost and result.get("ghost"):
            # Durability and fsync must not hold Run/Group/PB/queue locks.
            try:
                ghost_hash = app.state.blobs.put_json(result["ghost"])
            except (OSError, RuntimeError, ValueError, SQLAlchemyError):
                logger.warning("ghost_storage_unavailable",extra={"run_id":run_id})
    except VerifierStopping:
        # Keep the durable lease; a replacement can recover it after expiry.
        return True
    except BuildMismatch:
        failure, permanent = "build_mismatch", True
        logger.error("verification_build_mismatch", extra={"run_id": run_id, "worker_id": worker_id, "failure_code": failure})
    except VerificationError:
        failure, rejected = "invalid_replay", True
    except Exception as exc:
        logger.exception("verification_infrastructure_error", extra={"run_id": run_id, "worker_id": worker_id, "failure_code": "manifest_mismatch" if str(exc) == "Verifier manifest differs from pinned track manifest" else "verifier_unavailable"})
        failure = "verifier_unavailable"

    if aborting(app):
        return True
    pending = (run_id, token, pinned_manifest, result, failure, rejected, permanent,
               ghost_hash, creator_test, worker_id, queue_wait, started)
    if result is not None and failure is None:
        result.pop("ghost", None)  # Already immutable/published; keep only bounded timing/manifest proof.
        app.state.pending_finalization = pending
    # Failed SQL leaves the proof cached and the original fence intact.
    finalize(app, *pending)
    return True


def expire_unserviceable(app):
    """Release bounded admission after a prolonged absence of compatible capacity.

    Keep the original evidence and make it retryable with its original cohort;
    never count this as a cheating rejection or verification attempt.
    """
    with app.state.session_factory() as session:
        run = session.scalar(select(Run).where(
            Run.status.in_(("queued", "verifying")), Run.lease_until <= now(),
            Run.created_at <= now() - app.state.settings.worker_contract_wait_seconds,
        ).order_by(Run.created_at, Run.id).with_for_update(skip_locked=True).limit(1))
        if run is None:
            return False
        board = session.get(Board, run.board_id)
        capable = session.scalar(select(OperationState.id).where(
            OperationState.id.startswith("worker:"),
            OperationState.updated_at >= now()-app.state.settings.worker_stale_seconds,
            func.coalesce(OperationState.details["lifecycle"].as_string(), "running") == "running",
            worker_filter(OperationState.details["build"], board.manifest),
        ).limit(1))
        if capable:
            return False
        run.status, run.failure_code, run.finished_at = "failed", "build_unavailable", now()
        run.lease_token, run.lease_until = None, 0
        session.commit()
        return True


def finalize(app, run_id, token, pinned_manifest, result, failure, rejected, permanent,
             ghost_hash, creator_test, worker_id, queue_wait, started):
    settings = app.state.settings
    maximum_attempts = settings.max_job_attempts
    with app.state.session_factory() as session:
        # Run ownership is immutable. Discover it without a row lock, then use
        # the same Player -> Run order as retry/admission/account writers.
        player_id = session.scalar(select(Run.player_id).where(Run.id == run_id))
        player = session.scalar(select(Player).where(Player.id == player_id).with_for_update()
            .execution_options(populate_existing=True)) if player_id is not None else None
        run = session.scalar(select(Run).where(Run.id == run_id).with_for_update())
        if run is None or run.status != "verifying" or run.lease_token != token or run.lease_until <= now():
            logger.warning("verification_lease_lost", extra={"run_id": run_id, "worker_id": worker_id})
            app.state.pending_finalization = None
            return False
        if failure:
            terminal = permanent or rejected or run.attempts >= maximum_attempts
            run.status = "rejected" if rejected else "failed" if terminal else "queued"
            run.failure_code, run.lease_token = failure, None
            run.lease_until = 0 if terminal else now() + min(60, 2**run.attempts)
            run.finished_at = now() if terminal else None
            session.commit()
            logger.info("verification_unsuccessful", extra={"run_id": run_id, "worker_id": worker_id,
                "failure_code": failure, "verification_seconds": round(time.monotonic()-started, 4)})
            app.state.pending_finalization = None
            return True
        # Serialize PB projections with account restriction/test-identity changes.
        # Both writers lock Player before touching board visibility counters.
        test_disabled = (player.is_test_driver or pinned_manifest.get("test_population")) and not settings.test_drivers_enabled
        if player.disabled or player.deleted_at is not None or test_disabled:
            run.status, run.failure_code, run.finished_at, run.lease_token = (
                "rejected",
                "test_population_disabled" if test_disabled else "account_disabled",
                now(),
                None,
            )
            session.commit()
            app.state.pending_finalization = None
            return True
        run.status, run.time_ticks, run.lap_ticks = "verified", result["time_ticks"], result["lap_ticks"]
        run.finished_at, run.failure_code, run.lease_token, run.lease_until = now(), None, None, 0
        session.flush()
        if not creator_test:
            from .rivalry import accept_verified
            run.ghost_hash = ghost_hash
            accept_verified(session, run)
            from .challenges import accept_verified as accept_challenge
            accept_challenge(session, run)
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
        if getattr(settings, "telemetry_enabled", False):
            from .telemetry import append_server_event
            dimensions = {"track_version": version.id, "run_id": run.id, "ticket_id": run.ticket_id,
                          "car_id": board.vehicle_id,
                          "lap_count": len(run.lap_ticks)}
            if version.published_at is not None:
                dimensions.update(owner_id=track.owner_id, published_at=version.published_at)
            discovery = version.discovery or {}
            biome = discovery.get("theme", discovery.get("biome"))
            if biome:
                dimensions["biome"] = biome
            append_server_event(session, "creator_validated" if creator_test else "race_accepted",
                                run.id, run.player_id, dimensions, occurred_at=run.finished_at,
                                is_test_driver=player.is_test_driver)
        session.commit()
        logger.info("verification_complete", extra={"run_id": run_id, "time_ticks": result["time_ticks"],
            "worker_id": worker_id, "queue_wait_seconds": queue_wait,
            "verification_method":result.get("verification_method","canonical-replay"),
            "verification_compute_ms":result.get("verification_compute_ms"),
            "verification_seconds":round(time.monotonic()-started,4)})
    heartbeat(app,worker_id,phase="idle",last_verification_seconds=round(time.monotonic()-started,4),coalesce=True)
    app.state.pending_finalization = None
    return True


def process_worker_job(app) -> bool:
    # The long-running service performs background presentation work. Explicit
    # single-race diagnostic calls retain their verification-only behavior.
    if process_one(app, refresh_histograms=True):
        # Foreground work stays first; a bounded cleanup step also gets a turn
        # every sixteen completed jobs, so continuous racing cannot starve it.
        count = (getattr(app.state, "privacy_work_count", 0) + 1) % 16
        app.state.privacy_work_count = count
        if count == 0:
            from .privacy import cleanup_one
            cleanup_one(app)
        return True
    from .privacy import cleanup_one
    return cleanup_one(app)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--once", action="store_true", help="Process at most one currently eligible job")
    args = parser.parse_args()
    from .app import create_app

    app = create_app()
    run_worker(app, process_worker_job, once=args.once)


if __name__ == "__main__":
    main()
