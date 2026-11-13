"""Bounded offline controller process, separate from the service verifier API."""

import atexit
import hashlib
import json
import logging
import os
import re
import subprocess
import tempfile
import time
from contextlib import contextmanager
from pathlib import Path

from .verifier import MAX_REQUEST_BYTES, GodotVerifier

CONTROLLER_VERSION = "profiled-trajectory-6"
MAX_TRAJECTORY_CACHE_FILES = 128
PLANNING_TIMEOUT_SECONDS = 480
logger = logging.getLogger("bmt.test_driver_generator")


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


class GenerationTimedOut(RuntimeError):
    """Defer a bounded generation failure rather than retrying it indefinitely."""


@contextmanager
def controller_engine(settings):
    verifier = GodotVerifier(settings)
    try:
        verifier._check_engine()
        yield verifier
    finally:
        verifier.close()
        atexit.unregister(verifier.close)


def publish_trajectory(source, target):
    """Retain a complete derived plan before a later drive timeout or shutdown."""
    if target is None:
        return False
    try:
        raw = source.read_bytes() if source.stat().st_size <= 2_000_000 else b""
        value = json.loads(raw, parse_constant=_reject_nonfinite_cache)
        json.dumps(value, allow_nan=False)
        if (not isinstance(value, dict) or not isinstance(value.get("rows"), list)
                or not value["rows"] or not re.fullmatch(r"[a-f0-9]{64}", str(value.get("key", "")))):
            return False
    except (OSError, ValueError):
        return False  # Native output can still be in the middle of its write.
    with tempfile.NamedTemporaryFile(dir=target.parent, suffix=".tmp", delete=False) as stream:
        temporary = Path(stream.name)
        stream.write(raw)
    try:
        os.replace(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)
    _trim_trajectory_cache(target.parent)
    return True


def generate(settings, document, vehicle_id, traits, attempt=0, pace_scale=1.0, *, obstacle_detours=False,
             stop_event=None, deadline=None):
    if deadline is not None and time.monotonic() >= deadline:
        raise GenerationTimedOut("Local attempt exhausted its generation budget")
    with controller_engine(settings) as verifier, tempfile.TemporaryDirectory(prefix="bmt-test-drive-") as folder:
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
            concurrent = bool(getattr(stop_event, "concurrent", False))
            options = {"creationflags": subprocess.BELOW_NORMAL_PRIORITY_CLASS} if concurrent and os.name == "nt" else {}
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
                **options,
            )
            if concurrent and hasattr(os, "setpriority"):
                try:
                    os.setpriority(os.PRIO_PROCESS, process.pid, 19)
                except ProcessLookupError:
                    pass  # A prompt controller failure is checked below.
                except OSError:
                    process.kill()
                    process.wait()
                    raise RuntimeError("Cannot lower background controller priority") from None
            generation_started = time.monotonic()
            generation_id = hashlib.sha256(json.dumps(
                [CONTROLLER_VERSION, document, vehicle_id, traits, attempt, pace_scale, obstacle_detours],
                sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()[:24]
            logger.info("driver_generation_started", extra={"generation_id": generation_id})
            generation_timeout = max(verifier.timeout, PLANNING_TIMEOUT_SECONDS)
            deadline = min(deadline, time.monotonic() + generation_timeout) if deadline is not None else time.monotonic() + generation_timeout
            observed_bytes = 0
            trajectory_saved = False
            try:
                while process.poll() is None:
                    if not trajectory_saved:
                        trajectory_saved = publish_trajectory(trajectory_output, cache_path)
                        if trajectory_saved:
                            logger.info("driver_trajectory_cached", extra={"generation_id": generation_id})
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
                        logger.info("driver_generation_timed_out", extra={"generation_id": generation_id,
                            "generation_seconds": round(time.monotonic() - generation_started, 3)})
                        raise GenerationTimedOut("Test controller exceeded its bounded generation time")
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
                if not trajectory_saved:
                    publish_trajectory(trajectory_output, cache_path)
                logger.info("driver_generation_stopped", extra={"generation_id": generation_id,
                    "generation_seconds": round(time.monotonic() - generation_started, 3)})
        if stop_event is not None and stop_event.is_set():
            raise RuntimeError("Test controller stopped by worker shutdown")
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
        if process.returncode == 2 and response.get("ok") is False:
            raise DriverDidNotFinish(str(response.get("error", "Driver did not finish")))
        if (
            process.returncode != 0
            or response.get("ok") is not True
            or not isinstance(response.get("result"), dict)
        ):
            raise RuntimeError("Test controller failed")
        return response["result"]
