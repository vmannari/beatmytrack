"""Fail-closed adapter to the pinned canonical Godot simulation.

Untrusted JSON is data only. Every verification starts a fresh headless process,
track, vehicle and checkpoint session; no client timing or state is accepted.
"""

from __future__ import annotations

import copy
import json
import math
import re
import subprocess
import tempfile
import threading
from pathlib import Path
from typing import Any

REPLAY_SCHEMA = "bmt-replay-v1"
MAX_FRAMES = 216_000  # 30 minutes at the canonical 120 Hz.
MAX_TRACK_BYTES = 524_288
MAX_REQUEST_BYTES = 8 * 1024 * 1024
MAX_JSON_NODES = MAX_FRAMES * 5 + MAX_TRACK_BYTES + 1024
_ENGINE_SLOT = threading.BoundedSemaphore(1)


class VerificationError(ValueError):
    """The submitted track or replay is invalid, or did not finish legally."""


class VerifierUnavailable(RuntimeError):
    """The trusted verifier could not execute; never publish a result."""


def _json_bytes(value: Any, limit: int) -> bytes:
    # Bound nesting before the encoder/engine encounters malicious recursion.
    stack = [(value, 0)]
    nodes = 0
    while stack:
        item, depth = stack.pop()
        nodes += 1
        if depth > 12 or nodes > MAX_JSON_NODES:
            raise VerificationError("JSON structure exceeds verification bounds")
        if type(item) is dict:
            if any(type(key) is not str or len(key) > 80 for key in item):
                raise VerificationError("Invalid JSON field name")
            stack.extend((child, depth + 1) for child in item.values())
        elif type(item) is list:
            stack.extend((child, depth + 1) for child in item)
        elif type(item) is float:
            if not math.isfinite(item):
                raise VerificationError("Numbers must be finite")
        elif type(item) not in (str, int, bool, type(None)):
            raise VerificationError("Only JSON data is accepted")
    try:
        encoded = json.dumps(value, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode(
            "utf-8"
        )
    except (ValueError, OverflowError, RecursionError, UnicodeError) as exc:
        raise VerificationError("Invalid JSON data") from exc
    if len(encoded) > limit:
        raise VerificationError("JSON exceeds verification byte limit")
    return encoded


def validate_replay(replay: dict) -> None:
    if type(replay) is not dict or not (
        (set(replay) == {"schema", "frames"} and replay.get("schema") == REPLAY_SCHEMA)
        or (set(replay) == {"schema", "frames", "rewinds"} and replay.get("schema") == "bmt-replay-v2")
    ):
        raise VerificationError("Unsupported replay envelope")
    frames = replay["frames"]
    if type(frames) is not list or not 1 <= len(frames) <= MAX_FRAMES:
        raise VerificationError("Replay needs 1 to 216000 canonical input frames")
    for frame_index, frame in enumerate(frames):
        if type(frame) is not list or len(frame) not in (3, 4, 5) or any(type(value) is not int for value in frame):
            raise VerificationError("Each replay frame needs three to five quantized integers")
        if not -127 <= frame[0] <= 127 or not 0 <= frame[1] <= 255 or not 0 <= frame[2] <= 255 or (len(frame) >= 4 and not 0 <= frame[3] <= 255):
            raise VerificationError("Replay input outside quantized range")

        if len(frame) == 5 and (frame_index != 0 or frame[4] not in (1, 2)):
            raise VerificationError("Invalid launch marker")

    events = replay.get("rewinds", [])
    if type(events) is not list or len(events) > 3 or (replay["schema"] == "bmt-replay-v2" and not events):
        raise VerificationError("Replay must contain one to three rewinds")
    offset, tick = 0, 0
    receipts = set()
    for event in events:
        if type(event) is not dict or set(event) != {"receipt_id", "input_offset", "from_tick", "to_tick"}:
            raise VerificationError("Malformed rewind")
        receipt = event["receipt_id"]
        if type(receipt) is not str or len(receipt) != 36 or receipt in receipts:
            raise VerificationError("Invalid or duplicate resume receipt")
        receipts.add(receipt)
        if any(type(event[k]) is not int for k in ("input_offset", "from_tick", "to_tick")):
            raise VerificationError("Rewind ticks must be integers")
        if not offset < event["input_offset"] < len(frames):
            raise VerificationError("Rewind input offsets must increase within replay")
        if event["from_tick"] != tick + event["input_offset"] - offset:
            raise VerificationError("Rewind timeline mismatch")
        if event["to_tick"] < 0 or not 1 <= event["from_tick"] - event["to_tick"] <= 1200:
            raise VerificationError("Rewind exceeds 10 seconds")
        offset, tick = event["input_offset"], event["to_tick"]


class GodotVerifier:
    def __init__(self, settings: Any):
        self.binary = str(settings.godot_bin)
        self.project = Path(settings.game_project).resolve()
        self.timeout = float(settings.verifier_timeout_seconds)
        self._versions: dict | None = None
        self._engine_checked = False

    def _check_engine(self) -> None:
        if self._engine_checked:
            return
        try:
            pinned = (self.project.parent / "godot-version.txt").read_text(encoding="utf-8-sig").strip()
            result = subprocess.run([self.binary, "--version"], capture_output=True, timeout=10, check=False)
        except (OSError, subprocess.SubprocessError) as exc:
            raise VerifierUnavailable("Pinned Godot verifier is unavailable") from exc
        if result.returncode != 0 or result.stdout.decode("utf-8", "replace").strip() != pinned:
            raise VerifierUnavailable("Godot executable does not match godot-version.txt")
        self._engine_checked = True

    def _invoke(self, payload: dict) -> dict:
        # Shared by all adapter instances within one API/worker process. Reject
        # overload immediately rather than accumulating costly engine children.
        if not _ENGINE_SLOT.acquire(blocking=False):
            raise VerifierUnavailable("Canonical verifier is busy; retry later")
        try:
            return self._invoke_locked(payload)
        finally:
            _ENGINE_SLOT.release()

    def _invoke_locked(self, payload: dict) -> dict:
        request = _json_bytes(payload, MAX_REQUEST_BYTES)
        self._check_engine()
        with tempfile.TemporaryDirectory(prefix="bmt-verify-") as folder:
            directory = Path(folder)
            input_path, output_path = directory / "input.json", directory / "output.json"
            input_path.write_bytes(request)
            command = [
                self.binary,
                "--headless",
                "--path",
                str(self.project),
                "--script",
                "res://backend/runner.gd",
                "--",
                f"--input={input_path}",
                f"--output={output_path}",
            ]
            try:
                with (directory / "engine.log").open("wb") as log:
                    process = subprocess.run(
                        command,
                        stdin=subprocess.DEVNULL,
                        stdout=log,
                        stderr=subprocess.STDOUT,
                        timeout=self.timeout,
                        check=False,
                    )
                log_path = directory / "engine.log"
                if log_path.stat().st_size > 65536:
                    raise VerifierUnavailable("Verifier exceeded diagnostic output limit")
                diagnostics = log_path.read_text(encoding="utf-8", errors="replace")
                if re.search(r"SCRIPT ERROR:|(?:^|\s)ERROR:|Parse Error:", diagnostics, re.IGNORECASE):
                    raise VerifierUnavailable("Canonical verifier reported an engine error")
                result_limit = MAX_REQUEST_BYTES if payload.get("operation") == "run" else MAX_TRACK_BYTES + 4096
                if not output_path.is_file() or output_path.stat().st_size > result_limit:
                    raise VerifierUnavailable("Canonical verifier returned no bounded result")
                response = json.loads(output_path.read_text(encoding="utf-8"))
            except (OSError, subprocess.SubprocessError, ValueError) as exc:
                raise VerifierUnavailable("Canonical verification could not complete") from exc
            if type(response) is not dict or type(response.get("ok")) is not bool:
                raise VerifierUnavailable("Invalid canonical verifier response")
            if process.returncode == 2 and response["ok"] is False:
                raise VerificationError(str(response.get("error", "Verification rejected"))[:500])
            if (
                process.returncode != 0
                or response["ok"] is not True
                or type(response.get("result")) is not dict
            ):
                raise VerifierUnavailable("Canonical verifier failed closed")
            return response["result"]

    def manifest(self) -> dict:
        if self._versions is None:
            self._versions = self._invoke({"operation": "manifest"})
        return copy.deepcopy(self._versions)

    def validate_track(self, document: dict) -> dict:
        if type(document) is not dict:
            raise VerificationError("Track must be a JSON object")
        _json_bytes(document, MAX_TRACK_BYTES)
        return self._invoke({"operation": "track", "document": document})

    def prepare_track(self, document: dict) -> tuple[dict, dict]:
        """Normalize and validate an owner-approved legacy local track atomically."""
        if type(document) is not dict:
            raise VerificationError("Track must be a JSON object")
        _json_bytes(document, MAX_TRACK_BYTES)
        result = self._invoke({"operation": "prepare_track", "document": document})
        normalized, manifest = result.get("document"), result.get("manifest")
        if type(normalized) is not dict or type(manifest) is not dict:
            raise VerifierUnavailable("Canonical verifier returned no prepared track")
        _json_bytes(normalized, MAX_TRACK_BYTES)
        return normalized, manifest

    def verify_run(self, document: dict, replay: dict, vehicle_id: str, *, creator_test: bool = False) -> dict:
        if type(document) is not dict:
            raise VerificationError("Track must be a JSON object")
        _json_bytes(document, MAX_TRACK_BYTES)
        validate_replay(replay)
        if type(vehicle_id) is not str or vehicle_id not in self.manifest()["vehicles"]:
            raise VerificationError("Unsupported vehicle")
        result = self._invoke(
            {"operation": "creator_test" if creator_test else "run", "document": document, "replay": replay, "vehicle_id": vehicle_id}
        )
        ticks, laps, milliseconds = result.get("time_ticks"), result.get("lap_ticks"), result.get("time_ms")
        if (
            type(ticks) is not int
            or ticks != len(replay["frames"]) - sum(e["from_tick"] - e["to_tick"] for e in replay.get("rewinds", []))
            or type(milliseconds) is not int
            or milliseconds <= 0
            or type(laps) is not list
            or len(laps) != (1 if creator_test else 5)
            or any(type(tick) is not int or tick <= 0 for tick in laps)
            or sum(laps) != ticks
        ):
            raise VerifierUnavailable("Canonical result failed timing invariants")
        if not creator_test:
            validate_ghost(result.get("ghost"), ticks)
        return result


def validate_ghost(recording, race_ticks):
    """Derived presentation only; retain strict 20 Hz, duration and finite bounds."""
    if type(recording) is not dict or set(recording) != {"ticks", "poses"}:
        raise VerifierUnavailable("Canonical ghost is missing")
    duration, poses = recording["ticks"], recording["poses"]
    if (type(duration) not in (int, float) or not math.isfinite(duration) or not 0 < duration <= race_ticks
            or type(poses) is not list or not 2 <= len(poses) <= MAX_FRAMES // 6 + 7):
        raise VerifierUnavailable("Canonical ghost exceeds recording bounds")
    previous = -1
    for pose in poses:
        if (type(pose) is not list or len(pose) != 7
                or any(type(value) not in (int, float) or not math.isfinite(value) for value in pose)
                or not previous < pose[0] <= duration):
            raise VerifierUnavailable("Canonical ghost has malformed samples")
        previous = pose[0]
    if poses[0][0] != 0 or poses[-1][0] != duration:
        raise VerifierUnavailable("Canonical ghost endpoints do not match the race")
