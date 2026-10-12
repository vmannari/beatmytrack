import copy
import json
import subprocess
from pathlib import Path
from types import SimpleNamespace

import pytest
from sqlalchemy import select
from test_test_drivers import auth, bot_login, fleet
from test_test_drivers import drivers as drivers_fixture
from test_verifier import race_fixture as race_fixture_source
from test_verifier import real_verifier as real_verifier_source

from bmt_backend.background_work import BackgroundControl, BackgroundYielded
from bmt_backend.replay_wire import unpack_replay
from bmt_backend.track_models import Run
from bmt_backend.verifier import GodotVerifier, VerificationError, validate_replay
from bmt_backend.worker import process_one

drivers = drivers_fixture
race_fixture = race_fixture_source
real_verifier = real_verifier_source

@pytest.fixture(scope="module")
def proof(real_verifier, tmp_path_factory):
    folder = tmp_path_factory.mktemp("lightweight-proof")
    output = folder / "proof.json"
    root = Path(__file__).resolve().parents[2]
    command = [real_verifier.binary, "--headless", "--path", str(root / "game"), "--script",
        "res://tests/test_lightweight_verifier.gd", "--", f"--fixture={root / 'backend/tests/fixtures/verified_oval.json'}",
        f"--proof-output={output}"]
    result = subprocess.run(command, capture_output=True, timeout=90, check=False)
    assert result.returncode == 0, (result.stdout + result.stderr).decode(errors="replace")
    return json.loads(output.read_text())


@pytest.mark.godot
def test_trajectory_acceptance_rejects_bad_movement_without_simulation(real_verifier, race_fixture, proof):
    verifier = GodotVerifier(SimpleNamespace(godot_bin=real_verifier.binary,
        game_project=real_verifier.project, verifier_timeout_seconds=90, persistent_verifier=True))
    try:
        replay = {"schema":"bmt-trajectory-v1","input_count":race_fixture["time_ticks"],"race_proof":proof}
        baseline = verifier.verify_run(race_fixture["document"], replay, "compact")
        assert baseline["verification_method"] == "trajectory-v1"
        assert baseline["time_ticks"] == race_fixture["time_ticks"]
        assert baseline["lap_ticks"] == [2634, 2532, 2531, 2530, 2530]
        assert baseline["manifest"] == race_fixture["expected_manifest"]
        def forbidden_engine(*_args, **_kwargs):
            raise AssertionError("Race acceptance must not execute the engine")
        verifier._invoke = forbidden_engine
        path = {"schema":"bmt-race-path-v1","samples":[[row[0],row[1],row[2],row[6]] for row in proof["samples"]]}
        compact = {**replay,"race_proof":path}
        assert verifier.verify_run(race_fixture["document"],compact,"compact")["lap_ticks"] == baseline["lap_ticks"]
        rewind = {**compact,"input_count":12757+1200,"rewinds":[{"receipt_id":"00000000-0000-0000-0000-000000000001","input_offset":3600,"from_tick":3600,"to_tick":2400}]}
        assert verifier.verify_run(race_fixture["document"],rewind,"compact")["time_ticks"] == 12757
        reversed_path = {**compact,"race_proof":{"schema":path["schema"],"samples":list(reversed(path["samples"]))}}
        with pytest.raises(VerificationError):
            verifier.verify_run(race_fixture["document"],reversed_path,"compact")
        altered = copy.deepcopy(replay)
        altered["race_proof"]["samples"][1][1] += 40
        with pytest.raises(VerificationError,match="jumps"):
            verifier.verify_run(race_fixture["document"], altered, "compact")
        incomplete = copy.deepcopy(replay)
        incomplete["input_count"] -= 1
        with pytest.raises(VerificationError):
            verifier.verify_run(race_fixture["document"], incomplete, "compact")
        with pytest.raises(VerificationError,match="trajectory is required"):
            verifier.verify_run(race_fixture["document"],race_fixture["replay"],"compact")
        no_ghost = verifier.verify_run(race_fixture["document"], replay, "compact", capture_ghost=False)
        assert no_ghost["verification_method"] == "trajectory-v1" and no_ghost["ghost"] == {}
        # Steering/pedals are irrelevant to the trajectory contract.
        legacy = {"schema":"bmt-replay-v1","frames":[[0,0,0]]*12757,"race_proof":proof}
        assert verifier.verify_run(race_fixture["document"],legacy,"compact")["time_ticks"] == 12757
    finally:
        verifier.close()


@pytest.mark.parametrize("bad", [None, {}, {"schema": "bmt-race-proof-v1", "samples": []},
    {"schema": "bmt-race-proof-v1", "samples": [[0, 0, 0, 0, 0, 0, True, 0], [6, 0, 0, 0, 0, 0, 0, 0]]},
    {"schema": "bmt-race-proof-v1", "samples": [[0, 0, 0, 0, 0, 0, 0, 0], [6, float("nan"), 0, 0, 0, 0, 0, 0]]}])
def test_malformed_proof_fails_closed(bad):
    with pytest.raises(VerificationError):
        validate_replay({"schema": "bmt-replay-v1", "frames": [[0, 0, 0]] * 6, "race_proof": bad})


def test_packed_transport_preserves_evidence_and_pending_poll_budget():
    import base64

    from bmt_backend.runs import pending_poll_ms
    from bmt_backend.track_models import now
    evidence = {"schema": "bmt-race-proof-v1", "samples": [[0, 0., 0., 0., 0., 0., 0, 0.], [6, 0., 0., 0., 0., 0., 0, 0.]]}
    wire = {"schema": "bmt-packed-input-v1", "replay_schema": "bmt-replay-v1", "frame_count": 6,
        "controls": base64.b64encode(bytes([3, 127, 0, 0, 0, 0]) * 6).decode(), "race_proof": evidence}
    replay = unpack_replay(wire)
    validate_replay(replay)
    assert replay["race_proof"] == evidence and len(replay["frames"]) == 6
    run = SimpleNamespace(status="queued", created_at=now())
    assert pending_poll_ms(run) == 1000
    run.created_at -= 11
    assert pending_poll_ms(run) == 2500
    run.status = "verified"
    assert pending_poll_ms(run) == 0


@pytest.mark.godot
def test_real_http_worker_accepts_light_proof_and_retries_same_evidence(auth_app, auth_client, sign_in, real_verifier, race_fixture, proof):
    import uuid
    from dataclasses import replace
    auth_app.state.settings = replace(auth_app.state.settings, environment="test", allow_sync_track_validation=True)
    verifier = GodotVerifier(SimpleNamespace(godot_bin=real_verifier.binary,
        game_project=real_verifier.project, verifier_timeout_seconds=90, persistent_verifier=True))
    auth_app.state.verifier = verifier
    methods = []
    original = verifier.verify_run
    def observed(*args, **kwargs):
        result = original(*args, **kwargs)
        methods.append(result.get("verification_method", "canonical-replay"))
        return result
    verifier.verify_run = observed
    try:
        login = sign_in("Light proof driver")
        headers = {"Authorization": "Bearer " + login["access_token"]}
        def write(path, body, key=None):
            return auth_client.post("/v1" + path, json=body,
                headers={**headers, "Idempotency-Key": key or str(uuid.uuid4())})
        track = write("/tracks", {"name": "Light proof oval", "document": race_fixture["document"]})
        assert track.status_code == 201, track.text
        ticket = write("/run-tickets", {"version_id": track.json()["version_id"], "vehicle_id": "compact"})
        assert ticket.status_code == 201, ticket.text
        ghost = verifier.verify_canonical_diagnostic(race_fixture["document"],race_fixture["replay"],"compact")["ghost"]
        wire = {"schema":"bmt-trajectory-v1","input_count":race_fixture["time_ticks"],"race_proof":proof,"ghost":ghost}
        body = {"ticket_id": ticket.json()["ticket_id"], "replay": wire}
        key = str(uuid.uuid4())
        submitted = write("/runs", body, key)
        assert submitted.status_code == 202, submitted.text
        run_id = submitted.json()["run_id"]
        assert write("/runs", body, key).json()["run_id"] == run_id
        assert process_one(auth_app)
        assert methods == ["trajectory-v1"]
        result = auth_client.get("/v1/runs/" + run_id, headers=headers).json()
        assert result["status"] == "verified" and result["time_ticks"] == 12757
        assert result["lap_ticks"] == [2634, 2532, 2531, 2530, 2530]
        assert write("/runs", body, key).json()["run_id"] == run_id
        with auth_app.state.session_factory() as session:
            run = session.get(Run, run_id)
            assert auth_app.state.blobs.get_json(run.replay_hash)["race_proof"] == proof
            assert "frames" not in auth_app.state.blobs.get_json(run.replay_hash)
            assert run.ghost_hash
    finally:
        verifier.close()


def test_player_run_preempts_background_and_bypasses_older_artificial_jobs(drivers):
    population = fleet(drivers, count=1)
    bot = bot_login(drivers, population["profiles"][0])
    with drivers.factory() as session:
        from bmt_backend.track_models import TrackVersion
        version = session.scalar(select(TrackVersion.id).where(TrackVersion.state == "published"))
    def submit(login, artificial):
        ticket = drivers.client.post("/v1/run-tickets", json={"version_id": version, "vehicle_id": "compact",
            "test_population": artificial}, headers=auth(login)).json()
        response = drivers.client.post("/v1/runs", json={"ticket_id": ticket["ticket_id"],
            "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]] * 20}}, headers=auth(login))
        assert response.status_code == 202, response.text
        return response.json()["run_id"]
    bot_run = submit(bot, True)
    control = BackgroundControl(drivers.app)
    assert not control.is_set()  # Artificial backlog never interrupts generation.
    human_run = submit(drivers.login, False)
    control.next_check = 0
    with pytest.raises(BackgroundYielded):
        control.is_set()
    assert process_one(drivers.app)
    with drivers.factory() as session:
        assert session.get(Run, human_run).status == "verified"
        assert session.get(Run, bot_run).status == "queued"
    assert process_one(drivers.app)
    control.next_check = 0
    assert not control.is_set()
