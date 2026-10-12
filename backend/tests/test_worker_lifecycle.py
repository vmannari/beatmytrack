"""Restart correctness, operational visibility and safe diagnostic contracts."""
import json
import logging
import os
import signal
import subprocess
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from pathlib import Path
from types import SimpleNamespace

import pytest
from sqlalchemy import select
from test_domains import domain as domain_fixture
from test_domains import headers, public_course, submit, ticket

from bmt_backend.contracts import build_contract
from bmt_backend.observability import JsonFormatter
from bmt_backend.operations import competition_health, heartbeat
from bmt_backend.track_models import OperationState, PersonalBest, QueueCapacity, Run, now
from bmt_backend.verifier import GodotVerifier, VerifierStopping
from bmt_backend.worker import process_one
from bmt_backend.worker_lifecycle import WorkerControl, run_worker

domain = domain_fixture


def test_diagnostics_preserve_operational_fields_without_payloads():
    record = logging.LogRecord("bmt.worker", logging.INFO, "", 0, "verification_complete", (), None)
    record.worker_id, record.run_id = "worker-id", "run-id"
    record.verification_seconds, record.queue_wait_seconds = 1.2345, 8
    record.shutdown_seconds, record.stop_signal = 2.1, signal.SIGTERM
    record.access_token, record.replay, record.player_id = "private-token", {"private": "inputs"}, "private-player"
    value = json.loads(JsonFormatter().format(record))
    assert value["verification_seconds"] == 1.2345 and value["worker_id"] == "worker-id"
    assert value["queue_wait_seconds"] == 8 and value["shutdown_seconds"] == 2.1
    assert "private" not in json.dumps(value)
    try:
        raise RuntimeError("private exception text")
    except RuntimeError:
        record.exc_info = sys.exc_info()
    value = json.loads(JsonFormatter().format(record))
    assert value["exception_type"] == "RuntimeError" and "private" not in json.dumps(value)


@pytest.mark.parametrize("fails", [False, True])
def test_once_cleans_verifier_and_pool_even_on_failure(auth_app, monkeypatch, fails):
    calls = []
    monkeypatch.setattr(auth_app.state.verifier, "close", lambda: calls.append("close"))
    dispose = auth_app.state.engine.dispose
    monkeypatch.setattr(auth_app.state.engine, "dispose", lambda: (calls.append("dispose"), dispose()))
    previous = {s: signal.getsignal(s) for s in (signal.SIGTERM, signal.SIGINT)}
    def job(app):
        heartbeat(app, app.state.worker_id, build={"fixture": True})
        if fails:
            raise RuntimeError("job failed")
        return False
    if fails:
        with pytest.raises(RuntimeError, match="job failed"):
            run_worker(auth_app, job, once=True)
    else:
        run_worker(auth_app, job, once=True)
    assert calls == ["close", "dispose"]
    assert all(signal.getsignal(s) == handler for s, handler in previous.items())
    with auth_app.state.session_factory() as session:
        state = session.get(OperationState, "worker:" + auth_app.state.worker_id)
        assert state.details["lifecycle"] == "stopped"


def test_cleanup_failure_still_disposes_database(auth_app, monkeypatch):
    disposed = []
    def broken_close():
        raise OSError("cleanup fault")
    monkeypatch.setattr(auth_app.state.verifier, "close", broken_close)
    monkeypatch.setattr(auth_app.state.engine, "dispose", lambda: disposed.append(True))
    run_worker(auth_app, lambda app: False, once=True)
    assert disposed == [True]


def test_idle_shutdown_wakes_without_poll_delay(auth_app):
    control = WorkerControl()
    calls = []
    def job(app):
        calls.append(True)
        control.request_stop()
        return False
    started = time.monotonic()
    run_worker(auth_app, job, control=control)
    assert len(calls) == 1 and time.monotonic() - started < 0.8


def test_draining_cannot_be_revived_by_a_finishing_job(domain):
    build = build_contract(domain.app.state.verifier.manifest())
    heartbeat(domain.app, "worker", build=build, phase="verifying")
    assert competition_health(domain.app)["available_workers"] == 1
    heartbeat(domain.app, "worker", lifecycle="draining")
    heartbeat(domain.app, "worker", phase="idle", lifecycle="running")
    health = competition_health(domain.app)
    assert health["active_workers"] == health["available_workers"] == 0
    assert health["draining_workers"] == 1 and health["status"] == "worker_unavailable"
    assert domain.client.get("/healthz").status_code == 200
    heartbeat(domain.app, "worker", lifecycle="stopped")
    heartbeat(domain.app, "worker", build=build, lifecycle="running")
    assert competition_health(domain.app)["stopped_workers"] == 1
    heartbeat(domain.app, "replacement", build=build)
    health = competition_health(domain.app)
    assert health["available_workers"] == 1 and health["status"] == "ready"


def test_concurrent_first_heartbeats_preserve_build_and_drain(auth_app):
    barrier = threading.Barrier(2)
    def publish(details):
        barrier.wait(timeout=3)
        heartbeat(auth_app, "concurrent", **details)
    with ThreadPoolExecutor(max_workers=2) as pool:
        first = pool.submit(publish, {"build": {"fixture": True}})
        second = pool.submit(publish, {"lifecycle": "draining"})
        first.result(timeout=5)
        second.result(timeout=5)
    with auth_app.state.session_factory() as session:
        state = session.get(OperationState, "worker:concurrent")
        assert state.details == {"build": {"fixture": True}, "lifecycle": "draining"}


def test_stopped_control_prevents_race_and_validation_claims(domain):
    from bmt_backend.track_validation import process_one as validate_one
    version, _ = public_course(domain)
    run = submit(domain, ticket(domain, version, "Alice"), "Alice")
    control = domain.app.state.worker_control = WorkerControl()
    control.request_stop()
    assert not process_one(domain.app) and not validate_one(domain.app)
    with domain.factory() as session:
        row = session.get(Run, run["run_id"])
        assert row.status == "queued" and row.attempts == 0


def test_interrupted_verification_is_recoverable_without_duplicate_pb(domain, monkeypatch):
    version, _ = public_course(domain)
    run = submit(domain, ticket(domain, version, "Alice"), "Alice")
    original = domain.app.state.verifier.verify_run
    def stopping(*args, **kwargs):
        raise VerifierStopping("shutdown")
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", stopping)
    assert process_one(domain.app)
    with domain.factory() as session:
        row = session.get(Run, run["run_id"])
        assert row.status == "verifying" and row.lease_token and row.failure_code is None
        assert session.get(QueueCapacity, 1).pending == 1
        assert session.scalar(select(PersonalBest).where(PersonalBest.player_id == domain.players["Alice"])) is None
        row.lease_until = 0  # Simulate lease expiry; no wall-clock sleep or live player data.
        session.commit()
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", original)
    assert process_one(domain.app)
    assert not process_one(domain.app)
    with domain.factory() as session:
        row = session.get(Run, run["run_id"])
        assert row.status == "verified" and row.attempts == 2
        assert session.get(QueueCapacity, 1).pending == 0
        assert len(session.scalars(select(PersonalBest).where(PersonalBest.player_id == row.player_id)).all()) == 1


def test_health_reports_actual_processing_and_end_to_end_latency(domain):
    version, _ = public_course(domain)
    first = submit(domain, ticket(domain, version, "Alice"), "Alice")
    assert process_one(domain.app)
    second = submit(domain, ticket(domain, version, "Bob"), "Bob")
    third = submit(domain, ticket(domain, version, "Carol"), "Carol")
    stamp = now()
    with domain.factory() as session:
        for old in session.scalars(select(Run).where(Run.status == "verified", Run.id != first["run_id"])):
            old.finished_at = stamp - 301  # Keep the creator proof outside this five-minute metric window.
        verified = session.get(Run, first["run_id"])
        verified.created_at, verified.finished_at = stamp - 10, stamp
        failed = session.get(Run, second["run_id"])
        failed.status, failed.finished_at, failed.failure_code = "failed", stamp, "verifier_unavailable"
        rejected = session.get(Run, third["run_id"])
        rejected.status, rejected.finished_at, rejected.failure_code = "rejected", stamp, "invalid_replay"
        session.commit()
    health = competition_health(domain.app)
    assert health["verified_per_second_last_5_minutes"] == round(1 / 300, 4)
    assert health["failed_last_5_minutes"] == health["rejected_last_5_minutes"] == 1
    assert health["infrastructure_failure_rate_last_5_minutes"] == 0.5
    assert health["completion_latency_seconds_last_5_minutes"] == {"mean": 10, "max": 10}


def test_interrupted_validation_keeps_draft_and_recovers(domain, monkeypatch):
    from test_track_lifecycle import save

    from bmt_backend.track_models import TrackValidation, TrackVersion
    from bmt_backend.track_validation import process_one as validate_one
    version, _ = save(domain)
    original = domain.app.state.verifier.validate_track
    def cancelled(document):
        raise VerifierStopping("shutdown")
    monkeypatch.setattr(domain.app.state.verifier, "validate_track", cancelled)
    assert validate_one(domain.app)
    with domain.factory() as session:
        row = session.get(TrackValidation, version["version_id"])
        assert row.status == "validating" and row.lease_token and row.failure_code is None
        assert session.get(TrackVersion, row.version_id).content_hash
        row.lease_until = 0
        session.commit()
    monkeypatch.setattr(domain.app.state.verifier, "validate_track", original)
    assert validate_one(domain.app)
    with domain.factory() as session:
        row = session.get(TrackValidation, version["version_id"])
        assert row.status == "validated" and row.attempts == 2
        assert session.get(QueueCapacity, 1).pending == 0


def test_interrupted_rivalry_cannot_duplicate_points(domain, monkeypatch):
    from test_rivalry import join, rivalry_ticket, seed

    from bmt_backend.rivalry_models import RivalryBest, RivalryTicket
    seed(domain)
    group = join(domain)
    issued = rivalry_ticket(domain, group["group_id"])
    run = submit(domain, issued, "Alice")
    original = domain.app.state.verifier.verify_run
    def cancelled(*args, **kwargs):
        raise VerifierStopping("shutdown")
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", cancelled)
    assert process_one(domain.app)
    with domain.factory() as session:
        row = session.get(Run, run["run_id"])
        assert row.status == "verifying"
        assert session.scalar(select(RivalryBest).where(RivalryBest.group_id == group["group_id"])) is None
        assert session.get(RivalryTicket, row.ticket_id).outcome is None
        row.lease_until = 0
        session.commit()
    monkeypatch.setattr(domain.app.state.verifier, "verify_run", original)
    assert process_one(domain.app)
    with domain.factory() as session:
        bests = session.scalars(select(RivalryBest).where(RivalryBest.group_id == group["group_id"])).all()
        assert len(bests) == 1 and bests[0].run_id == run["run_id"]
        outcome = session.get(RivalryTicket, issued["ticket_id"]).outcome
        assert outcome["points_delta"] > 0
    standings = domain.client.get(f"/v1/rivalry/{group['group_id']}", headers=headers(domain, "Alice")).json()["standings"]
    points = next(row["points"] for row in standings if row["name"] == "Alice")
    assert not process_one(domain.app)
    with domain.factory() as session:
        assert session.get(RivalryTicket, issued["ticket_id"]).outcome == outcome
    standings = domain.client.get(f"/v1/rivalry/{group['group_id']}", headers=headers(domain, "Alice")).json()["standings"]
    assert next(row["points"] for row in standings if row["name"] == "Alice") == points


def test_grace_deadline_cancels_busy_verifier_and_excludes_draining_worker(auth_app, monkeypatch):
    control = WorkerControl()
    cancelled = threading.Event()
    observed = []
    auth_app.state.settings = replace(auth_app.state.settings, worker_shutdown_grace_seconds=1)
    monkeypatch.setattr(auth_app.state.verifier, "request_stop", cancelled.set, raising=False)
    def job(app):
        heartbeat(app, app.state.worker_id, build={"fixture": True})
        control.request_stop()
        assert cancelled.wait(3)
        with app.state.session_factory() as session:
            observed.append(session.get(OperationState, "worker:" + app.state.worker_id).details["lifecycle"])
        return True
    started = time.monotonic()
    run_worker(auth_app, job, control=control)
    assert observed == ["draining"] and control.abort.is_set()
    assert 0.9 <= time.monotonic() - started < 3


def test_verifier_stop_cancels_active_child_and_rejects_new_work(tmp_path):
    verifier = GodotVerifier(SimpleNamespace(godot_bin="", game_project=tmp_path,
        verifier_timeout_seconds=90, persistent_verifier=False))
    marker = tmp_path / "child-pid"
    result = []
    def work():
        try:
            verifier._run_process([sys.executable, "-c",
                "import pathlib,os,time;pathlib.Path(__import__('sys').argv[1]).write_text(str(os.getpid()));time.sleep(60)",
                str(marker)], timeout=90, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except VerifierStopping:
            result.append("stopped")
    thread = threading.Thread(target=work)
    thread.start()
    try:
        deadline = time.monotonic() + 5
        while not marker.exists() and time.monotonic() < deadline:
            time.sleep(0.02)
        assert marker.exists()
        verifier.request_stop()
        thread.join(timeout=5)
        assert not thread.is_alive() and result == ["stopped"]
        with pytest.raises(VerifierStopping):
            verifier.validate_track({"shape": "oval"})
    finally:
        verifier.request_stop()
        thread.join(timeout=5)
        verifier.close()


@pytest.mark.skipif(os.name == "nt", reason="Windows process termination does not deliver POSIX SIGTERM")
@pytest.mark.parametrize("mode,stop_signal", [("graceful", signal.SIGTERM), ("cancel", signal.SIGTERM),
    ("kill", None), ("cancel", signal.SIGINT)])
def test_real_signals_and_kill_recovery(tmp_path, mode, stop_signal):
    harness = Path(__file__).with_name("worker_signal_probe.py")
    def wait_for(name):
        deadline = time.monotonic() + 15
        while not (tmp_path / name).exists() and process.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        assert (tmp_path / name).exists(), f"Probe failed to reach {name}"
    with (tmp_path / "probe.log").open("wb") as log:
        process = subprocess.Popen([sys.executable, str(harness), str(tmp_path), mode], stdout=log, stderr=log)
        try:
            wait_for("entered")
            started = time.monotonic()
            if mode == "kill":
                process.kill()
                process.wait(timeout=5)
            else:
                process.send_signal(stop_signal)
                wait_for("draining")
                if mode == "graceful":
                    (tmp_path / "release").touch()
                assert process.wait(timeout=5) == 0
                assert time.monotonic() - started < 5
                report = json.loads((tmp_path / "report.json").read_text())
                setup = json.loads((tmp_path / "setup.json").read_text())
                assert report["runs"][setup["second"]]["status"] == "queued"
                assert report["verifier_closed"] and report["health"]["available_workers"] == 0
                assert report["health"]["stopped_workers"] == 2  # Setup proof worker plus supervised worker.
                first = report["runs"][setup["first"]]
                assert first["status"] == ("verified" if mode == "graceful" else "verifying")
                assert report["pb_count"] == (2 if mode == "graceful" else 1)
        finally:
            if process.poll() is None:
                process.kill()
            process.wait(timeout=5)
        if mode != "graceful":
            recovered = subprocess.run([sys.executable, str(harness), str(tmp_path), "recover"],
                stdout=log, stderr=log, timeout=15, check=False)
            assert recovered.returncode == 0
            report = json.loads((tmp_path / "report.json").read_text())
            assert report["pb_count"] == 3 and report["pending"] == 0
