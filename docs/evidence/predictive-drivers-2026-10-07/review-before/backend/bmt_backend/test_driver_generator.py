"""Bounded offline controller process, separate from the service verifier API."""

import json
import re
import subprocess
import tempfile
import time
from pathlib import Path

from .verifier import MAX_REQUEST_BYTES, GodotVerifier


class DriverDidNotFinish(RuntimeError):
    pass


def generate(settings, document, vehicle_id, traits, attempt=0, pace_scale=1.0, *, obstacle_detours=False, stop_event=None):
    verifier = GodotVerifier(settings)
    verifier._check_engine()
    with tempfile.TemporaryDirectory(prefix="bmt-test-drive-") as folder:
        directory = Path(folder)
        source, output = directory / "input.json", directory / "output.json"
        source.write_text(
            json.dumps(
                {
                    "document": document,
                    "vehicle_id": vehicle_id,
                    "traits": traits,
                    "attempt": attempt,
                    "pace_scale": pace_scale,
                    "obstacle_detours": obstacle_detours,
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
            try:
                while process.poll() is None:
                    if stop_event is not None and stop_event.is_set():
                        raise RuntimeError("Test controller stopped by worker shutdown")
                    if time.monotonic() >= deadline:
                        raise subprocess.TimeoutExpired(process.args, verifier.timeout)
                    time.sleep(0.05)
            finally:
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
        if process.returncode == 2 and response.get("ok") is False:
            raise DriverDidNotFinish(str(response.get("error", "Driver did not finish")))
        if (
            process.returncode != 0
            or response.get("ok") is not True
            or not isinstance(response.get("result"), dict)
        ):
            raise RuntimeError("Test controller failed")
        return response["result"]
