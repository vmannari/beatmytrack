"""Bounded offline controller process, separate from the service verifier API."""

import hashlib
import json
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path

from .verifier import MAX_REQUEST_BYTES, GodotVerifier

CONTROLLER_VERSION = "profiled-trajectory-4"
MAX_TRAJECTORY_CACHE_FILES = 128


def _reject_nonfinite_cache(token):
    raise ValueError("Nonfinite derived trajectory cache")


def _trim_trajectory_cache(directory):
    candidates = []
    for entry in directory.glob("*.json"):
        try:
            candidates.append((entry.stat().st_mtime_ns, entry.name, entry))
        except OSError:
            continue  # Another generator may already have evicted this entry.
    for _, _, entry in sorted(candidates)[:-MAX_TRAJECTORY_CACHE_FILES]:
        if entry.resolve().parent == directory.resolve():
            entry.unlink(missing_ok=True)  # Only replaceable derived cache files.


class DriverDidNotFinish(RuntimeError):
    pass


def generate(settings, document, vehicle_id, traits, attempt=0, pace_scale=1.0, *, obstacle_detours=False, stop_event=None):
    verifier = GodotVerifier(settings)
    verifier._check_engine()
    with tempfile.TemporaryDirectory(prefix="bmt-test-drive-") as folder:
        directory = Path(folder)
        source, output = directory / "input.json", directory / "output.json"
        trajectory_output = directory / "trajectory.json"
        cache_path = None
        cached = None
        if getattr(settings, "object_dir", None):
            cache_dir = Path(settings.object_dir).parent / "driver-trajectories"
            cache_dir.mkdir(parents=True, exist_ok=True)
            key = hashlib.sha256(json.dumps([document, vehicle_id], sort_keys=True,
                                             separators=(",", ":"), allow_nan=False).encode()).hexdigest()
            cache_path = cache_dir / (key + ".json")
            if cache_path.is_file() and cache_path.stat().st_size <= 2_000_000:
                try:
                    candidate = json.loads(cache_path.read_text(encoding="utf-8"),
                                           parse_constant=_reject_nonfinite_cache)
                    if isinstance(candidate, dict):
                        cached = candidate
                except (ValueError, OSError):
                    pass  # Derived cache corruption regenerates; player files are untouched.
        source.write_text(
            json.dumps(
                {
                    "document": document,
                    "vehicle_id": vehicle_id,
                    "traits": traits,
                    "attempt": attempt,
                    "pace_scale": pace_scale,
                    "obstacle_detours": obstacle_detours,
                    "trajectory": cached,
                    "trajectory_output": str(trajectory_output),
                },
                allow_nan=False,
            ),
            encoding="utf-8",
        )
        with (directory / "engine.log").open("wb") as log:
            process = subprocess.Popen(
                [
                    verifier.binary,
                    "--headless",
                    "--path",
                    str(verifier.project),
                    "--script",
                    "res://backend/generate_test_driver.gd",
                    "--",
                    f"--input={source}",
                    f"--output={output}",
                ],
                stdin=subprocess.DEVNULL,
                stdout=log,
                stderr=subprocess.STDOUT,
            )
            deadline = time.monotonic() + verifier.timeout
            observed_bytes = 0
            try:
                while process.poll() is None:
                    size = (directory / "engine.log").stat().st_size
                    if size > 65536:
                        raise RuntimeError("Test controller exceeded diagnostic output limit")
                    if size != observed_bytes:
                        observed_bytes = size
                        diagnostics = (directory / "engine.log").read_text(encoding="utf-8", errors="replace")
                        if re.search(r"SCRIPT ERROR:|(?:^|\s)ERROR:|Parse Error:", diagnostics, re.IGNORECASE):
                            raise RuntimeError("Test controller reported an engine error")
                    if stop_event is not None and stop_event.is_set():
                        raise RuntimeError("Test controller stopped by worker shutdown")
                    if time.monotonic() >= deadline:
                        raise subprocess.TimeoutExpired(process.args, verifier.timeout)
                    time.sleep(0.05)
            finally:
                if process.poll() is None:
                    if os.name == "nt":
                        # The Windows console launcher can own a native child.
                        # Stop only this spawned tree, so its log closes too.
                        subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"],
                                       check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    if process.poll() is None:
                        process.kill()
                process.wait()
        log_path = directory / "engine.log"
        if log_path.stat().st_size > 65536 or re.search(
            r"SCRIPT ERROR:|(?:^|\s)ERROR:|Parse Error:",
            log_path.read_text(encoding="utf-8", errors="replace"),
            re.IGNORECASE,
        ):
            raise RuntimeError("Test controller reported an engine error")
        if not output.is_file() or output.stat().st_size > MAX_REQUEST_BYTES:
            raise RuntimeError("Test controller returned no bounded recording")
        response = json.loads(output.read_text(encoding="utf-8"))
        # The native loader validates content/physics/rules/handling identity.
        # Publish even after an honest noncompletion, so slower retry profiles
        # share the same planning work. Concurrent writers replace atomically.
        if cache_path is not None and trajectory_output.is_file() and trajectory_output.stat().st_size <= 2_000_000:
            with tempfile.NamedTemporaryFile(dir=cache_path.parent, suffix=".tmp", delete=False) as cache_file:
                temporary = Path(cache_file.name)
                cache_file.write(trajectory_output.read_bytes())
            try:
                os.replace(temporary, cache_path)
            finally:
                temporary.unlink(missing_ok=True)
            _trim_trajectory_cache(cache_path.parent)
        if process.returncode == 2 and response.get("ok") is False:
            raise DriverDidNotFinish(str(response.get("error", "Driver did not finish")))
        if (
            process.returncode != 0
            or response.get("ok") is not True
            or not isinstance(response.get("result"), dict)
        ):
            raise RuntimeError("Test controller failed")
        return response["result"]
