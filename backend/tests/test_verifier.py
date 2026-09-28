from __future__ import annotations

import copy
import json
import os
import subprocess
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


@pytest.fixture(scope="module")
def race_fixture():
    return json.loads((Path(__file__).parent / "fixtures" / "verified_oval.json").read_text())


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
        [0, 0, 0, 0],
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
        subprocess, "run", lambda *a, **k: SimpleNamespace(returncode=0, stdout=b"4.0.stable")
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

    monkeypatch.setattr(subprocess, "run", bad_process)
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

        def reply(self, status, data):
            body = json.dumps(data).encode()
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
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
                        {"track_id": "track-test", "idempotency_key": self.headers.get("Idempotency-Key")},
                    )
            elif self.path == "/v1/auth/logout":
                self.reply(200, {})
            else:
                self.reply(404, {})

        def do_GET(self):
            calls.append((self.path, self.headers.get("Authorization"), None, {}))
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
    assert "11 checks, 0 failures" in process.stdout
    assert "SCRIPT ERROR" not in process.stderr
    mutations = [call for call in calls if call[0] == "/v1/tracks"]
    assert len(mutations) == 2 and mutations[0][2:] == mutations[1][2:]
    assert not any(call[0] == "/leaked-credentials" for call in calls)
