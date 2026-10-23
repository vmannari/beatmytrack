"""Ordinary verified player results must not restart an unfinished AI race."""
import dataclasses
import json
import os
import subprocess
import sys
import threading
import time
from pathlib import Path
from types import SimpleNamespace

import pytest
from sqlalchemy import select
from test_publication_intents import request as request_publication
from test_test_drivers import KEY, auth
from test_test_drivers import drivers as _drivers
from test_verifier import real_verifier as _real_verifier

from bmt_backend.identity_models import Player
from bmt_backend.operations import competition_health
from bmt_backend.track_models import Run
from bmt_backend.worker import process_worker_job
from bmt_backend.worker_lifecycle import WorkerControl, run_worker

drivers = _drivers
real_verifier = _real_verifier


class LocalAPI:
    """Use the real authenticated routes without a live account or service."""
    url = "http://127.0.0.1:18181"
    upload_recovery = True

    def __init__(self, fixture):
        self.fixture = fixture
        self.tokens = {}
        self.stop_event = None

    def call(self, method, path, body=None, subject=None, idempotency=None, operator=False):
        if self.stop_event is not None and self.stop_event.is_set():
            raise RuntimeError("Owned test service is stopping")
        headers = {"X-Dev-Auth-Key": KEY} if operator else {}
        if subject:
            if subject not in self.tokens:
                response = self.fixture.client.post("/v1/auth/development", json={
                    "subject": subject, "display_name": subject}, headers={"X-Dev-Auth-Key": KEY})
                assert response.status_code == 200, response.text
                self.tokens[subject] = response.json()["access_token"]
            headers["Authorization"] = "Bearer " + self.tokens[subject]
        if idempotency:
            headers["Idempotency-Key"] = idempotency
        response = self.fixture.client.request(method, "/v1" + path, json=body, headers=headers)
        assert response.is_success, response.text
        return response.json()


def wait_for(predicate, message, seconds=5):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.01)
    raise AssertionError(message)


@pytest.mark.parametrize("player_results", [0, 5])
def test_service_keeps_one_ai_drive_during_player_results_and_stops_owned_work(
        drivers, monkeypatch, player_results):
    app = drivers.app
    app.state.settings = dataclasses.replace(app.state.settings, godot_bin="isolated-controlled-generator")
    app.state.automatic_driver_api = LocalAPI(drivers)
    response = drivers.client.post("/v1/rivalry/join", json={"vehicle_id": "compact",
        "test_population": True, "automatic_test_drivers": True}, headers=auth(drivers.login))
    assert response.status_code == 200, response.text
    group = response.json()
    started, release, cancelled = threading.Event(), threading.Event(), threading.Event()
    starts, errors = [], []

    def held_generate(settings, document, vehicle, traits, attempt=0, pace_scale=1.0, *, stop_event=None,
                      **kwargs):
        starts.append((document["id"], traits["seed"], attempt, pace_scale))
        started.set()
        try:
            while not release.wait(0.01):
                if stop_event.is_set():
                    cancelled.set()
                    raise RuntimeError("Controlled generator stopped")
        except Exception:
            cancelled.set()
            raise
        return {"manifest": app.state.verifier.manifest(), "time_ticks": 100, "mistakes": 0,
                "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]] * 20}}

    monkeypatch.setattr("bmt_backend.test_driver_generator.generate", held_generate)
    control = WorkerControl()

    def serve():
        try:
            run_worker(app, process_worker_job, control=control, install_signals=False)
        except Exception as error:  # noqa: BLE001 - surface worker-thread failures in its owning test.
            errors.append(error)

    service = threading.Thread(target=serve)
    service.start()
    try:
        assert started.wait(5), "Idle service never started its first AI race"
        for slot in range(player_results):
            issued = drivers.client.post(f"/v1/rivalry/{group['group_id']}/tickets",
                json={"slot": slot}, headers=auth(drivers.login))
            assert issued.status_code == 201, issued.text
            uploaded = drivers.client.post("/v1/runs", json={"ticket_id": issued.json()["ticket_id"],
                "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]] * 20}},
                headers=auth(drivers.login))
            assert uploaded.status_code == 202, uploaded.text
            run_id = uploaded.json()["run_id"]

            def human_verified(run_id=run_id):
                with drivers.factory() as session:
                    return session.get(Run, run_id).status == "verified"

            wait_for(human_verified, "Player verification waited for the unfinished AI race")
            assert len(starts) == 1 and not cancelled.is_set(), "Player submission restarted the AI race"
            assert competition_health(app)["available_workers"] == 1
        if player_results:
            release.set()

            def rival_verified():
                with drivers.factory() as session:
                    return session.scalar(select(Run.id).join(Player).where(
                        Player.is_test_driver.is_(True), Run.status == "verified")) is not None

            wait_for(rival_verified, "The original AI race did not reach ordinary verification")
            assert starts.count(starts[0]) == 1
    finally:
        control.request_stop()
        service.join(3)
        if service.is_alive():
            release.set()
            service.join(5)
        assert not service.is_alive(), "Service left an owned generation task behind"
    assert not errors
    if not player_results:
        assert cancelled.is_set(), "Shutdown did not cancel its owned generation"


def test_generation_timeouts_defer_then_retire_only_the_failed_attempt(tmp_path, monkeypatch):
    from test_domains import FakeVerifier

    from bmt_backend import test_population_tool as tool
    from bmt_backend.test_driver_generator import GenerationTimedOut

    manifest = FakeVerifier().manifest()
    failed = {"id": "a" * 64, "subject": "test-racer", "slot": 0, "version_id": "first",
              "attempt": 0, "due": 0, "group_id": "group", "status": "waiting"}
    other = {**failed, "id": "b" * 64, "version_id": "second"}
    plan = {"manifest": manifest, "profiles": [{"subject": "test-racer"}], "jobs": [failed, other],
            "mode": "automatic", "ends_at": 9999, "vehicle_id": "compact"}
    clock = [100]
    uploads = []

    class API:
        def call(self, method, path, *args, **kwargs):
            if path.startswith("/dev/"):
                return {"manifest": manifest, "server_now": clock[0]}
            if path.endswith("/tickets"):
                return {"ticket_id": "second-ticket", "expires_at": 9999}
            if path == "/runs":
                uploads.append(kwargs.get("idempotency"))
                return {"run_id": "second-run"}
            if path == "/runs/second-run":
                return {"status": "verified", "time_ticks": 100, "failure_code": None}
            raise AssertionError(path)

    def recording(api, plan, job, *args, **kwargs):
        if job["id"] == failed["id"]:
            raise GenerationTimedOut("Controlled timeout")
        return {"replay": {"frames": [[0, 255, 0]]}, "time_ticks": 100, "mistakes": 0}

    monkeypatch.setattr(tool, "recording", recording)
    monkeypatch.setattr(tool, "now", lambda: clock[0])
    path = tmp_path / "plan.json"
    api = API()
    for failure in range(1, 4):
        tool.tick(api, plan, None, path, maximum=1)
        assert failed["timeout_failures"] == failure and "ticket" not in failed and "run_id" not in failed
        assert failed["status"] == ("waiting" if failure < 3 else "uncompleted")
        assert failed["due"] > clock[0]
        if failure == 1:
            tool.tick(api, plan, None, path, maximum=1)
            assert other["status"] == "submitted" and len(uploads) == 1
        clock[0] = failed["due"]
    tool.tick(api, plan, None, path, maximum=1)
    saved = json.loads(path.read_text())
    assert saved["jobs"][0]["status"] == "uncompleted"
    assert saved["jobs"][1]["status"] == "verified" and len(uploads) == 1


def test_stopping_background_api_cannot_start_a_new_upload(monkeypatch):
    from bmt_backend.test_population_tool import API

    requests = []

    def request(session, method, url, **kwargs):
        requests.append((method, url))
        return SimpleNamespace(ok=True, json=lambda: {"test_drivers": True, "development_auth": True})

    monkeypatch.setattr("requests.Session.request", request)
    cancelled = threading.Event()
    api = API("http://127.0.0.1:18181", "isolated-test-key", stop_event=cancelled)
    cancelled.set()
    with pytest.raises(RuntimeError, match="stopping"):
        api.call("POST", "/runs", {}, subject="owned-test-driver")
    assert len(requests) == 1 and requests[0][0] == "GET"


@pytest.mark.parametrize("reason", ["shutdown", "timeout"])
def test_background_engine_is_lower_priority_and_reaped_on_cancellation(tmp_path, monkeypatch, reason):
    from bmt_backend import test_driver_generator as controller

    children = []
    popen = subprocess.Popen

    class Verifier:
        binary, project, timeout = sys.executable, tmp_path, 0.1

        def __init__(self, settings):
            pass

        def _check_engine(self):
            pass

    def spawn(command, **kwargs):
        if "--script" not in command:
            return popen(command, **kwargs)
        if os.name == "nt":
            assert kwargs["creationflags"] == subprocess.BELOW_NORMAL_PRIORITY_CLASS
        child = popen([sys.executable, "-c", "import time;time.sleep(30)"], **kwargs)
        children.append(child)
        return child

    class Control:
        concurrent = True

        def is_set(self):
            if hasattr(os, "getpriority"):
                assert os.getpriority(os.PRIO_PROCESS, children[0].pid) == 19
            return reason == "shutdown"

    monkeypatch.setattr(controller, "GodotVerifier", Verifier)
    monkeypatch.setattr(subprocess, "Popen", spawn)
    monkeypatch.setattr(controller, "PLANNING_TIMEOUT_SECONDS", 0)
    exception = RuntimeError if reason == "shutdown" else controller.GenerationTimedOut
    with pytest.raises(exception):
        controller.generate(SimpleNamespace(object_dir=str(tmp_path / "objects")), {}, "compact", {},
                            stop_event=Control())
    assert len(children) == 1 and children[0].poll() is not None


def test_publication_verifies_without_cancelling_the_owned_background_task(drivers, monkeypatch):
    from bmt_backend.community import TERMS_VERSION

    app = drivers.app
    app.state.settings = dataclasses.replace(app.state.settings, local_drafts_only=True,
        godot_bin="isolated-controlled-generator")
    accepted = drivers.client.post("/v1/community/terms", json={"version": TERMS_VERSION, "accepted": True},
                                   headers=auth(drivers.login))
    assert accepted.status_code == 200, accepted.text
    proof_calls = []

    def verify(document, replay, vehicle_id, *, creator_test=False):
        proof_calls.append(True)
        assert creator_test and replay["schema"] == "bmt-trajectory-v1"
        return {"time_ticks": replay["input_count"], "lap_ticks": [replay["input_count"]],
                "manifest": app.state.verifier.validate_track(document)}

    monkeypatch.setattr(app.state.verifier, "verify_run", verify)
    entered, cancelled = threading.Event(), threading.Event()
    control = WorkerControl()
    starts, errors = [], []

    def drive(app, *, generation_control=None):
        starts.append(True)
        entered.set()
        try:
            while not generation_control.is_set():
                time.sleep(0.01)
        finally:
            cancelled.set()
        return False

    monkeypatch.setattr("bmt_backend.test_population_batch.drive_idle", drive)

    def serve():
        try:
            run_worker(app, process_worker_job, control=control, install_signals=False)
        except Exception as error:  # noqa: BLE001 - surface worker-thread failures in its owning test.
            errors.append(error)

    service = threading.Thread(target=serve)
    service.start()
    try:
        assert entered.wait(5)
        intent = request_publication(drivers, auth=auth(drivers.login))

        def published():
            response = drivers.client.get("/v1/me/publications/" + intent["publication_id"],
                                           headers=auth(drivers.login))
            assert response.status_code == 200, response.text
            return response.json()["state"] == "published"

        wait_for(published, "Publication waited for background generation")
        assert starts == [True] and not cancelled.is_set()
        assert len(proof_calls) == 1
    finally:
        control.request_stop()
        service.join(5)
        assert not service.is_alive()
    assert cancelled.is_set() and not errors


@pytest.mark.godot
def test_background_native_drive_keeps_exact_recording_during_foreground_verification(
        tmp_path, real_verifier, monkeypatch):
    from bmt_backend.test_driver_generator import generate
    from bmt_backend.test_drivers import profile

    root = Path(__file__).resolve().parents[2]
    document = json.loads((root / "backend/tests/fixtures/verified_oval.json").read_text())["document"]
    settings = SimpleNamespace(godot_bin=real_verifier.binary, game_project=real_verifier.project,
        verifier_timeout_seconds=90, object_dir=str(tmp_path / "ordinary/objects"))
    traits = profile(27, 6, 13, 0.42, 0.58)[2]
    original = generate(settings, document, "compact", traits)
    settings.object_dir = str(tmp_path / "background/objects")
    running, cancel = threading.Event(), threading.Event()
    results, errors, processes = [], [], []
    popen = subprocess.Popen

    def spawn(command, **kwargs):
        child = popen(command, **kwargs)
        if "res://backend/generate_test_driver.gd" in command:
            processes.append(child)
            if os.name == "nt":
                assert kwargs["creationflags"] == subprocess.BELOW_NORMAL_PRIORITY_CLASS
        return child

    class Control:
        concurrent = True

        def is_set(self):
            if not running.is_set() and hasattr(os, "getpriority"):
                assert os.getpriority(os.PRIO_PROCESS, processes[0].pid) == 19
            running.set()
            return cancel.is_set()

    monkeypatch.setattr(subprocess, "Popen", spawn)

    def drive():
        try:
            results.append(generate(settings, document, "compact", traits, stop_event=Control()))
        except Exception as error:  # noqa: BLE001 - surface native-thread failures in its owning test.
            errors.append(error)

    thread = threading.Thread(target=drive)
    thread.start()
    try:
        assert running.wait(10), str(errors)
        verified = real_verifier.verify_run(document, original["replay"], "compact")
        thread.join(60)
        assert not thread.is_alive() and not errors
        assert len(processes) == 1 and processes[0].poll() == 0
        assert results[0]["replay"] == original["replay"]
        assert results[0]["time_ticks"] == original["time_ticks"] == verified["time_ticks"]
        assert len(verified["lap_ticks"]) == 5
    finally:
        cancel.set()
        thread.join(10)
