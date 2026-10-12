from __future__ import annotations

import copy
import json
import os
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from types import SimpleNamespace

import pytest

from bmt_backend.verifier import (
    _ENGINE_SLOT,
    MAX_FRAMES,
    GodotVerifier,
    VerificationError,
    VerifierUnavailable,
    _json_bytes,
    validate_replay,
)

ROOT = Path(__file__).resolve().parents[2]


@pytest.mark.godot
def test_retained_over_and_under_rejection_verifies_exactly(real_verifier):
    """Owner's rejected inputs exercise the first bridge exit on lap three."""
    fixtures = ROOT / "game" / "tests" / "fixtures"
    document = json.loads((fixtures / "over_and_under.json").read_text())
    replay = json.loads((fixtures / "over_and_under_rejected_inputs.json").read_text())
    result = real_verifier.verify_run(document, replay, "compact")
    assert result["manifest"]["rules_key"] == "standing-5-road-gates-v19"
    assert result["time_ticks"] == len(replay["frames"]) == 7786
    assert result["lap_ticks"] == [1627, 1412, 1426, 1553, 1768]
    assert result["time_ms"] == 64880
    # The fix must still reject missing finish input and trailing scored input.
    for frames in (replay["frames"][:-1], replay["frames"] + [[0, 0, 0]]):
        with pytest.raises(VerificationError):
            real_verifier.verify_run(document, {**replay, "frames": frames}, "compact")


def test_variable_width_route_survives_json_without_relaxing_geometry(real_verifier):
    import struct

    document = json.loads((Path(__file__).parent / "fixtures" / "variable_width_oval.json").read_text())
    # This fixture has the same decimal-rounding failure as Dust cloud, unlike
    # the original constant-width oval whose integer widths round-trip exactly.
    assert any(width != struct.unpack("f", struct.pack("f", width))[0] for width in document["widths"])
    manifest = real_verifier.validate_track(document)
    assert manifest["track_content_hash"] == "891ac9d4343552baf8d8a99f266a75d5d4e9cace36709562fe0930f3c76dda06"
    altered = copy.deepcopy(document)
    altered["widths"][1] += 0.00001
    with pytest.raises(VerificationError, match="Regenerate the automatic route"):
        real_verifier.validate_track(altered)


@pytest.fixture(scope="module")
def race_fixture():
    return json.loads((Path(__file__).parent / "fixtures" / "verified_oval.json").read_text())


def test_spline_gate_rules_do_not_relabel_historical_boards(race_fixture):
    from bmt_backend.contracts import current_manifest
    from bmt_backend.runs import board_manifest

    previous = copy.deepcopy(race_fixture["expected_manifest"])
    previous["rules_key"] = "standing-5-road-gates-v18"
    assert race_fixture["expected_manifest"]["rules_key"] == "standing-5-road-gates-v19"
    assert current_manifest(previous)["rules_key"] == "standing-5-road-gates-v19"
    assert previous["rules_key"] == "standing-5-road-gates-v18"  # Stored immutable revision is not rewritten.
    current_board = board_manifest(SimpleNamespace(manifest=previous), "compact")
    previous_board = {**current_board, "rules_key": "standing-5-road-gates-v18"}
    from bmt_backend.track_models import digest

    assert current_board["rules_key"] == "standing-5-road-gates-v19"
    assert digest(current_board) != digest(previous_board)  # New attempts never merge into the old board.


@pytest.fixture(scope="module")
def real_verifier():
    binary = os.environ.get("BMT_GODOT_BIN") or os.environ.get("GODOT_BIN")
    if not binary:
        candidate = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
        if candidate.is_file():
            binary = str(candidate)
    if not binary:
        pytest.skip("Pinned Godot unavailable; set BMT_GODOT_BIN for canonical integration tests")
    return GodotVerifier(
        SimpleNamespace(
            godot_bin=binary,
            game_project=os.environ.get("BMT_GAME_PROJECT", ROOT / "game"),
            verifier_timeout_seconds=90,
        )
    )


def test_validated_saved_route_is_compiled_without_regeneration(real_verifier, race_fixture):
    original = race_fixture["document"]
    rounded = copy.deepcopy(original)
    # Still within automatic-route validation tolerance, but a distinct immutable
    # document. Recompiling regenerated points would silently discard this input.
    rounded["points"][77][0] += 0.0005
    baseline = real_verifier.validate_track(original)
    revised = real_verifier.validate_track(rounded)
    assert baseline["track_content_hash"] != revised["track_content_hash"]
    assert baseline == race_fixture["expected_manifest"]


def test_server_accepts_overlapping_bridge_decks(real_verifier):
    document = json.loads((Path(__file__).parent / "fixtures" / "bridge_junction.json").read_text())
    result = real_verifier.validate_track(document)
    assert result["compiler_version"] == "creator-compiler-22"
    assert result["laps"] == 5 and result["track_content_hash"]


def test_server_accepts_five_point_spline(real_verifier):
    document = json.loads((ROOT / "game/tests/fixtures/spline_circuit.json").read_text())
    manifest = real_verifier.validate_track(document)
    assert manifest["compiler_version"] == "creator-compiler-22"
    assert manifest["laps"] == 5 and manifest["track_content_hash"]
    assert manifest == real_verifier.validate_track(copy.deepcopy(document))


@pytest.mark.parametrize("field,value", [
    ("spline_points", [[0, 0]] * 4),
    ("spline_points", [[0, 0], [12, 0], [12, 0], [36, 0], [48, 0]]),
    ("spline_points", [[0, 0], [12, 0], ["script", 8], [36, 0], [48, 0]]),
    ("point_widths", [10, 6, 21, 7, 12]),
    ("point_widths", [10] * 6),
])
def test_server_rejects_invalid_spline_as_data(real_verifier, field, value):
    document = json.loads((ROOT / "game/tests/fixtures/spline_circuit.json").read_text())
    document["pieces"][0][field] = value
    with pytest.raises(VerificationError):
        real_verifier.validate_track(document)


@pytest.mark.parametrize(
    "frame",
    [
        [128, 0, 0],
        [-128, 0, 0],
        [0, -1, 0],
        [0, 256, 0],
        [0, 0, 256],
        [0.0, 0, 0],
        [False, 0, 0],
        [0, 0],
        [0, 0, 0, 256],
        [0, 0, 0, -1],
        [0, 0, 0, True],
        [0, 0, 0, 0, 0],
    ],
)
def test_rejects_non_quantized_or_out_of_range_input(frame):
    with pytest.raises(VerificationError):
        validate_replay({"schema": "bmt-replay-v1", "frames": [frame]})


@pytest.mark.parametrize(
    "replay",
    [
        None,
        {},
        {"schema": "bmt-replay-v1", "frames": []},
        {"schema": "bmt-replay-v1", "frames": [[0, 0, 0]], "time_ms": 1},
        {"schema": "bmt-replay-v1", "frames": [[0, 0, 0]], "events": []},
    ],
)
def test_rejects_client_state_time_and_empty_replay(replay):
    with pytest.raises(VerificationError):
        validate_replay(replay)


def test_frame_and_json_resource_bounds():
    with pytest.raises(VerificationError):
        validate_replay({"schema": "bmt-replay-v1", "frames": [[0, 0, 0]] * (MAX_FRAMES + 1)})
    for value in [float("nan"), float("inf"), {1: "not a JSON key"}]:
        with pytest.raises(VerificationError):
            _json_bytes(value, 100)
    deep = {}
    for _ in range(15):
        deep = {"nested": deep}
    with pytest.raises(VerificationError):
        _json_bytes(deep, 10000)
    with pytest.raises(VerificationError):
        _json_bytes({"name": "x" * 200}, 100)


def test_wrong_engine_version_fails_closed(monkeypatch):
    verifier = GodotVerifier(
        SimpleNamespace(godot_bin="wrong", game_project=ROOT / "game", verifier_timeout_seconds=1)
    )
    monkeypatch.setattr(
        verifier, "_run_process", lambda *a, **k: SimpleNamespace(returncode=0, stdout=b"4.0.stable")
    )
    with pytest.raises(VerifierUnavailable, match="godot-version"):
        verifier.manifest()


def test_process_timeout_fails_closed(monkeypatch):
    verifier = GodotVerifier(
        SimpleNamespace(godot_bin="fake", game_project=ROOT / "game", verifier_timeout_seconds=1)
    )
    verifier._engine_checked = True

    def timeout(*args, **kwargs):
        raise subprocess.TimeoutExpired("fake", 1)

    monkeypatch.setattr(subprocess, "run", timeout)
    with pytest.raises(VerifierUnavailable):
        verifier.manifest()


def test_engine_concurrency_is_bounded_per_process():
    verifier = GodotVerifier(
        SimpleNamespace(godot_bin="fake", game_project=ROOT / "game", verifier_timeout_seconds=1)
    )
    assert _ENGINE_SLOT.acquire(blocking=False)
    try:
        with pytest.raises(VerifierUnavailable, match="busy"):
            verifier.manifest()
    finally:
        _ENGINE_SLOT.release()


def test_zero_exit_with_script_error_does_not_publish(monkeypatch):
    verifier = GodotVerifier(
        SimpleNamespace(godot_bin="fake", game_project=ROOT / "game", verifier_timeout_seconds=1)
    )
    verifier._engine_checked = True

    def bad_process(command, **kwargs):
        kwargs["stdout"].write(b"SCRIPT ERROR: hostile malformed output\n")
        output = next(item[9:] for item in command if item.startswith("--output="))
        Path(output).write_text('{"ok":true,"result":{"time_ticks":1}}')
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(verifier, "_run_process", bad_process)
    with pytest.raises(VerifierUnavailable, match="engine error"):
        verifier.manifest()


@pytest.mark.godot
def test_real_engine_manifest_pins_every_competitive_config(real_verifier):
    manifest = real_verifier.manifest()
    assert manifest["engine_version"] == (ROOT / "godot-version.txt").read_text().strip()
    assert manifest["tick_rate"] == 120 and manifest["laps"] == 5
    assert set(manifest["vehicles"]) == {"compact", "pickup", "classic", "formula", "kart"}
    assert len({car["config_hash"] for car in manifest["vehicles"].values()}) == 5
    assert all(len(car["config_hash"]) == 64 for car in manifest["vehicles"].values())


@pytest.mark.godot
def test_real_five_lap_race_replays_identically(real_verifier, race_fixture):
    info = real_verifier.validate_track(race_fixture["document"])
    result = real_verifier.verify_run(race_fixture["document"], race_fixture["replay"], "compact")
    assert result["manifest"] == info
    assert result["time_ticks"] == race_fixture["time_ticks"] == 12757
    assert result["time_ms"] == 106308
    assert result["lap_ticks"] == [2634, 2532, 2531, 2530, 2530]
    assert result == real_verifier.verify_run(race_fixture["document"], race_fixture["replay"], "compact")


@pytest.mark.godot
@pytest.mark.parametrize("change", ["truncate", "append", "stationary"])
def test_real_tampered_replay_cannot_manufacture_finish(real_verifier, race_fixture, change):
    replay = copy.deepcopy(race_fixture["replay"])
    if change == "truncate":
        replay["frames"] = replay["frames"][:-1]
    elif change == "append":
        replay["frames"].append([0, 0, 0])
    else:
        replay["frames"] = [[0, 0, 0]] * len(replay["frames"])
    with pytest.raises(VerificationError):
        real_verifier.verify_run(race_fixture["document"], replay, "compact")


@pytest.mark.godot
@pytest.mark.parametrize(
    "change", ["manual_route", "disconnected", "malformed_piece", "unsafe_path", "no_start"]
)
def test_real_track_rejects_routes_scripts_and_malformed_data(real_verifier, race_fixture, change):
    doc = copy.deepcopy(race_fixture["document"])
    if change == "manual_route":
        doc["points"][10] = [0, 0]
    elif change == "disconnected":
        doc["pieces"][0]["length"] -= 4
    elif change == "malformed_piece":
        doc["pieces"][0]["kind"] = "taper"
        doc["pieces"][0]["width"] = []
        doc["pieces"][0]["narrow_width"] = 6
    elif change == "unsafe_path":
        doc["script"] = "res://backend/generate_fixture.gd"
    else:
        del doc["start_line"]
    with pytest.raises(VerificationError):
        real_verifier.validate_track(doc)


@pytest.mark.godot
def test_godot_http_adapter_refreshes_without_losing_idempotency(real_verifier):
    # Test the real Godot HTTP stack against an isolated deterministic HTTP peer.
    calls = []

    class Peer(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def reply(self, status, data, headers=None):
            body = json.dumps(data).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            for key,value in (headers or {}).items():
                self.send_header(key,value)
            self.end_headers()
            self.wfile.write(body)

        def do_POST(self):
            payload = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
            calls.append(
                (self.path, self.headers.get("Authorization"), self.headers.get("Idempotency-Key"), payload)
            )
            if self.path == "/v1/auth/development":
                assert self.headers.get("X-Dev-Auth-Key") == "test-development-key"
                self.reply(
                    200,
                    {"access_token": "old-token", "refresh_token": "refresh-one", "player": {"id": "player"}},
                )
            elif self.path == "/v1/auth/refresh":
                assert payload == {"refresh_token": "refresh-one"}
                assert not self.headers.get("Authorization")
                self.reply(
                    200,
                    {"access_token": "new-token", "refresh_token": "refresh-two", "player": {"id": "player"}},
                )
            elif self.path == "/v1/tracks":
                if self.headers.get("Authorization") == "Bearer old-token":
                    self.reply(401, {"detail": "EXPIRED"})
                else:
                    assert self.headers.get("Authorization") == "Bearer new-token"
                    self.reply(
                        201,
                        {"track_id": "track-test", "version_id": "version-test", "idempotency_key": self.headers.get("Idempotency-Key")},
                    )
            elif self.path == "/v1/auth/logout":
                self.reply(200, {})
            else:
                self.reply(404, {})

        def do_GET(self):
            calls.append((self.path, self.headers.get("Authorization"), None, {}))
            if self.path == "/v1/conditional":
                if self.headers.get("If-None-Match") == '"fixture"':
                    self.send_response(304)
                    self.send_header("Content-Length","0")
                    self.end_headers()
                else:
                    self.reply(200,{"immutable":"body"},{"ETag":'"fixture"'})
                return
            self.send_response(302)
            self.send_header("Location", "/leaked-credentials")
            self.send_header("Content-Length", "0")
            self.end_headers()

    real_verifier._check_engine()
    server = ThreadingHTTPServer(("127.0.0.1", 0), Peer)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        # Adapter is a client artifact, not included in the minimal verifier image.
        process = subprocess.run(
            [
                real_verifier.binary,
                "--headless",
                "--path",
                str(ROOT / "game"),
                "--script",
                "res://backend/test_client.gd",
                "--",
                f"--endpoint=http://127.0.0.1:{server.server_port}",
            ],
            capture_output=True,
            text=True,
            timeout=40,
            check=False,
        )
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=2)
    assert process.returncode == 0, process.stdout + process.stderr
    assert "13 checks, 0 failures" in process.stdout
    assert "SCRIPT ERROR" not in process.stderr
    mutations = [call for call in calls if call[0] == "/v1/tracks"]
    assert len(mutations) == 2 and mutations[0][2:] == mutations[1][2:]
    assert not any(call[0] == "/leaked-credentials" for call in calls)


def test_real_creator_practice_proof(real_verifier):
    # Produced by TestPractice through the real game's input controls and recorder.
    path = ROOT / "build/creator-practice-proof.json"
    if not path.exists():
        pytest.skip("Run scripts/dev.ps1 -Action TestPractice first")
    proof = json.loads(path.read_text())
    result = real_verifier.verify_run(proof["document"], proof["replay"], "compact", creator_test=True)
    assert len(result["lap_ticks"]) == 1
    assert result["time_ticks"] == len(proof["replay"]["frames"])
    with pytest.raises(VerificationError):
        real_verifier.verify_run(proof["document"], proof["replay"], "compact")
    incomplete = {**proof["replay"], "frames": proof["replay"]["frames"][:-1]}
    with pytest.raises(VerificationError):
        real_verifier.verify_run(proof["document"], incomplete, "compact", creator_test=True)


@pytest.mark.parametrize("handbrake", [0, 127, 255])
def test_accepts_quantized_handbrake(handbrake):
    validate_replay({"schema": "bmt-replay-v1", "frames": [[0, 0, 0, handbrake]]})


@pytest.mark.godot
def test_real_verifier_applies_handbrake(real_verifier, race_fixture):
    replay = copy.deepcopy(race_fixture["replay"])
    replay["frames"] = [frame + [255] for frame in replay["frames"]]
    # Ignoring the fourth channel would incorrectly accept the original trajectory.
    with pytest.raises(VerificationError):
        real_verifier.verify_run(race_fixture["document"], replay, "compact")


@pytest.mark.parametrize("previous", ["arcade-planar-0.39", "arcade-planar-0.40", "arcade-planar-0.41", "arcade-planar-0.42", "arcade-planar-0.43", "arcade-planar-0.44", "arcade-planar-0.45", "arcade-planar-0.46", "arcade-planar-0.47", "arcade-planar-0.48"])
def test_handbrake_board_upgrade_preserves_immutable_track(race_fixture, previous):
    from bmt_backend.runs import board_manifest
    manifest = copy.deepcopy(race_fixture["expected_manifest"])
    manifest["physics_version"] = previous
    original = copy.deepcopy(manifest)
    upgraded = board_manifest(SimpleNamespace(manifest=manifest), "compact")
    assert upgraded["physics_version"] == "arcade-planar-0.50"
    assert upgraded["track_content_hash"] == manifest["track_content_hash"]
    assert manifest == original


@pytest.mark.godot
def test_standalone_verifier_contains_complete_handbrake_model(real_verifier, race_fixture, tmp_path):
    project = tmp_path / "canonical"
    subprocess.run([
        sys.executable, str(ROOT / "backend/deploy/stage_verifier.py"),
        "--repo", str(ROOT), "--destination", str(project),
    ], check=True, capture_output=True, timeout=30)
    imported = subprocess.run([
        real_verifier.binary, "--headless", "--editor", "--path", str(project), "--import",
    ], check=True, capture_output=True, timeout=90)
    assert b"SCRIPT ERROR:" not in imported.stdout + imported.stderr
    verifier = GodotVerifier(SimpleNamespace(
        godot_bin=real_verifier.binary,
        game_project=project,
        verifier_timeout_seconds=90,
    ))
    assert verifier.validate_track(race_fixture["document"]) == race_fixture["expected_manifest"]
    spline = json.loads((ROOT / "game/tests/fixtures/spline_circuit.json").read_text())
    assert verifier.validate_track(spline) == real_verifier.validate_track(spline)
    verifier.verify_run(race_fixture["document"], race_fixture["replay"], "compact")


def test_maximum_four_channel_finished_race(real_verifier, race_fixture):
    frames = race_fixture["replay"]["frames"]
    idle = [[0, 0, 255, 255]] * (MAX_FRAMES - len(frames))
    replay = {"schema": "bmt-replay-v1", "frames": idle + [frame[:3] + [0] for frame in frames]}
    result = real_verifier.verify_run(race_fixture["document"], replay, "compact")
    assert result["time_ticks"] == MAX_FRAMES
    assert len(result["lap_ticks"]) == 5 and sum(result["lap_ticks"]) == MAX_FRAMES


@pytest.mark.parametrize("marker", [1, 2])
def test_launch_marker_valid_only_in_first_frame(marker):
    validate_replay({"schema": "bmt-replay-v1", "frames": [[0, 255, 0, 0, marker], [0, 255, 0]]})
    for frames in ([[0, 0, 0], [0, 255, 0, 0, marker]], [[0, 0, 0, 0, 0]], [[0, 0, 0, 0, 3]]):
        with pytest.raises(VerificationError):
            validate_replay({"schema": "bmt-replay-v1", "frames": frames})


def test_early_launch_delay_verifies_in_standalone_runner(real_verifier, race_fixture):
    replay = copy.deepcopy(race_fixture["replay"])
    replay["frames"] = [[0, 255, 0, 0, 2]] + [[0, 255, 0]] * 71 + replay["frames"]
    result = real_verifier.verify_run(race_fixture["document"], replay, race_fixture["vehicle_id"])
    assert result["time_ticks"] == race_fixture["time_ticks"] + 72
    assert result["manifest"]["rules_key"] == "standing-5-road-gates-v19"
