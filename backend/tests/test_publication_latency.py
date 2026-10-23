"""Publication scheduling stays independent and acceptance remains authoritative."""

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from types import SimpleNamespace

import pytest
from sqlalchemy import func, select
from test_domains import domain as domain_fixture
from test_lightweight_verifier import creator_proof as creator_proof_fixture
from test_lightweight_verifier import race_fixture as race_fixture_fixture
from test_lightweight_verifier import real_verifier as real_verifier_fixture
from test_publication_intents import publications as publications_fixture
from test_publication_intents import request, status

from bmt_backend import service_worker
from bmt_backend.commerce import lock_entitlements
from bmt_backend.commerce_models import PublicationSlot
from bmt_backend.loadtest import rss_bytes
from bmt_backend.operations import competition_health
from bmt_backend.publication_models import PublicationIntent
from bmt_backend.publication_worker import process_job
from bmt_backend.publications import CONTRACT_FIELDS
from bmt_backend.track_models import Run, TrackVersion, new_id, now
from bmt_backend.verifier import _ENGINE_SLOT, GodotVerifier
from bmt_backend.worker_lifecycle import WorkerControl

domain = domain_fixture
publications = publications_fixture
creator_proof = creator_proof_fixture
race_fixture = race_fixture_fixture
real_verifier = real_verifier_fixture


def test_prompt_polling_is_bounded_and_status_does_not_claim(publications):
    queued = request(publications)
    assert queued["poll_after_ms"] == 1000
    identity = queued["publication_id"]
    assert status(publications, identity)["poll_after_ms"] == 1000
    with publications.factory() as session:
        intent = session.get(PublicationIntent, identity)
        assert intent.attempts == 0 and intent.status == "queued"
        intent.created_at = now() - 11
        session.commit()
    assert status(publications, identity)["poll_after_ms"] == 2500
    publications.app.state.worker_id = new_id()
    assert process_job(publications.app)
    assert status(publications, identity)["poll_after_ms"] == 0


def test_publication_lane_never_runs_competition_or_maintenance(publications, monkeypatch):
    import bmt_backend.rivalry_planning
    import bmt_backend.worker

    def forbidden(*args, **kwargs):
        pytest.fail("Publication lane entered competition or maintenance")
    monkeypatch.setattr(bmt_backend.worker, "process_one", forbidden)
    monkeypatch.setattr(bmt_backend.rivalry_planning, "maintain", forbidden)
    queued = request(publications)
    publications.app.state.worker_id = new_id()
    assert process_job(publications.app)
    assert status(publications, queued["publication_id"])["state"] == "published"
    # A publication-only process must not make competition appear available.
    assert competition_health(publications.app)["available_workers"] == 0
    assert not process_job(publications.app)
    publications.app.state.worker_control = WorkerControl()
    publications.app.state.worker_control.request_stop()
    assert not process_job(publications.app)


@pytest.mark.parametrize("telemetry", [False, True])
def test_supervisor_starts_and_stops_publication_lane_without_telemetry(monkeypatch, telemetry):
    started, stopped = [], []
    handlers = {}

    class Child:
        pid = 42
        code = None

        def poll(self):
            return self.code

        def send_signal(self, value):
            stopped.append((self.role, value))
            self.code = 0

        def wait(self, **kwargs):
            return self.code

    def factory(role, command):
        started.append((role, command))
        child = Child()
        child.role = role
        return child

    def stop_on_sleep(_seconds):
        handlers[signal.SIGTERM](signal.SIGTERM, None)

    monkeypatch.setattr(service_worker, "_adopt_descendants", lambda: None)
    monkeypatch.setattr(service_worker, "_reap_adopted", lambda: False)
    monkeypatch.setattr(service_worker, "_kill_group", lambda child: False)
    monkeypatch.setattr(service_worker.signal, "signal", lambda key, value: handlers.__setitem__(key, value))
    monkeypatch.setattr(service_worker.time, "sleep", stop_on_sleep)
    assert service_worker.supervise(telemetry_enabled=telemetry, child_factory=factory) == 0
    expected = ["worker", "publication"] + (["product"] if telemetry else [])
    assert [role for role, command in started] == expected
    assert started[1][1][-1] == "bmt_backend.publication_worker"
    assert stopped == [(role, signal.SIGTERM) for role in expected]


@pytest.mark.godot
def test_real_publications_complete_while_competition_engine_is_busy(
        auth_app, auth_client, sign_in, real_verifier, race_fixture, creator_proof, tmp_path):
    """A separate OS process must bypass the process-wide competition engine slot."""
    from bmt_backend.community import TERMS_VERSION

    login = sign_in("Publication timing")
    auth = {"Authorization": "Bearer " + login["access_token"]}

    def post(path, value):
        return auth_client.post("/v1" + path, json=value,
            headers={**auth, "Idempotency-Key": new_id()})

    assert post("/community/terms", {"version": TERMS_VERSION, "accepted": True}).status_code == 200
    with auth_app.state.session_factory() as session:
        lock_entitlements(session, login["player"]["id"]).slots = 8
        session.commit()
    # Parent only prepares authoritative client contracts. The worker receives
    # new immutable documents and has never compiled any of them beforehand.
    client_verifier = GodotVerifier(SimpleNamespace(godot_bin=real_verifier.binary,
        game_project=real_verifier.project, verifier_timeout_seconds=90, persistent_verifier=True))
    bodies = []
    try:
        for index in range(3):
            document = {**race_fixture["document"], "id": "publication_timing_" + str(index),
                "name": "Publication timing " + str(index), "creator": login["player"]["display_name"]}
            manifest = client_verifier.validate_track(document)
            contract = {key: manifest[key] for key in CONTRACT_FIELDS if key != "config_hash"}
            contract["config_hash"] = manifest["vehicles"]["compact"]["config_hash"]
            bodies.append({"name": document["name"], "document": document,
                "vehicle_id": "compact", "contract": contract, "replay": creator_proof})
    finally:
        client_verifier.close()
    config = {"database_url": auth_app.state.settings.database_url,
        "object_dir": auth_app.state.settings.object_dir, "environment": "test",
        "godot_bin": real_verifier.binary, "game_project": str(real_verifier.project)}
    (tmp_path / "worker.json").write_text(json.dumps(config))
    output = (tmp_path / "worker.log").open("w")
    child = subprocess.Popen([sys.executable, str(Path(__file__).with_name("publication_latency_probe.py")),
        str(tmp_path)], stdout=output, stderr=output)
    durations = []
    memory = []
    try:
        deadline = time.monotonic() + 30
        while not (tmp_path / "ready").exists() and child.poll() is None and time.monotonic() < deadline:
            time.sleep(0.02)
        assert (tmp_path / "ready").exists(), (tmp_path / "worker.log").read_text()
        pids = json.loads((tmp_path / "ready").read_text())
        memory.append({role: rss_bytes(pid) for role, pid in pids.items()})
        assert _ENGINE_SLOT.acquire(blocking=False)
        try:
            for content in bodies:
                started = time.perf_counter()
                response = post("/publications", content)
                assert response.status_code == 202, response.text
                identity = response.json()["publication_id"]
                deadline = time.monotonic() + 20
                while time.monotonic() < deadline:
                    response = auth_client.get("/v1/me/publications/" + identity, headers=auth)
                    assert response.status_code == 200
                    state = response.json()
                    if state["state"] in ("failed", "published"):
                        break
                    time.sleep(0.02)
                assert state["state"] == "published", state
                durations.append(time.perf_counter() - started)
                memory.append({role: rss_bytes(pid) for role, pid in pids.items()})
        finally:
            _ENGINE_SLOT.release()
        with auth_app.state.session_factory() as session:
            assert session.scalar(select(func.count()).select_from(PublicationSlot)) == 3
            assert session.scalar(select(func.count()).select_from(TrackVersion)) == 3
            assert session.scalar(select(func.count()).select_from(Run).where(Run.status == "verified")) == 3
        report = {"publication_seconds": durations, "competition_engine_held": True,
            "cold_track_each_time": True, "worker_and_engine_rss_bytes": memory,
            "scope": "Local HTTP, SQLite, local objects, warmed worker engine; sampled RSS is not peak memory"}
        print(json.dumps(report))
        target = os.environ.get("BMT_PUBLICATION_BENCHMARK_REPORT")
        if target:
            Path(target).write_text(json.dumps(report, indent=2))
    finally:
        (tmp_path / "stop").touch()
        try:
            child.wait(timeout=10)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait(timeout=5)
        output.close()
    assert child.returncode == 0, (tmp_path / "worker.log").read_text()
