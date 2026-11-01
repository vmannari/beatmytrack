"""Offline collector contract: loading is sampled and final poll is retained."""
import contextlib
import io
import json
import subprocess
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

import collect

PACKAGE = "org.beatmytrack.rendererprobe.gl20261031"
commands = []
missing_layer = False
missing_gate = False


def fake_run(args, **kwargs):
    commands.append(args)
    command = " ".join(args)
    if "pidof" in command:
        text = "4321\n"
    elif "activity activities" in command:
        text = f"topResumedActivity=ActivityRecord{{ {PACKAGE}/.Main }}\n"
    elif "SurfaceFlinger --list" in command:
        text = "" if missing_layer else f"SurfaceView[{PACKAGE}/.Main](BLAST)\n"
    elif "SurfaceFlinger --latency" in command:
        text = "16666666\n100 200 300\n400 500 600\n"
    else:
        raise AssertionError(command)
    return subprocess.CompletedProcess(args, 0, text, "")


class FakeLogcat:
    def __init__(self, args, **kwargs):
        commands.append(args)
        gate = "" if missing_gate else ('BMT_PERF_GATE_READY renderer=gl_compatibility\n'
                                       'BMT_PERF_GATE_START ticks_us=1000\n')
        self.stdout = io.StringIO(gate + 'BMT_PERF_BEGIN load_star_first\n'
                                  'BMT_PERF_CASE {"phase":"load_star_first"}\n'
                                  'BMT_PERF_FINISHED done\n')
        self.returncode = None

    def poll(self):
        return None

    def terminate(self):
        self.returncode = 0

    def communicate(self, timeout):
        return None, ""


def main():
    global missing_layer, missing_gate
    folder = Path("build/android-renderer-comparison-tests")
    folder.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(dir=folder) as temp:
        out = Path(temp) / "out"
        args = ["collect.py", "--adb", "fake-adb", "--serial", "test", "--package", PACKAGE,
                "--out", str(out), "--duration", "5"]
        with patch.object(sys, "argv", args), patch.object(collect.subprocess, "run", fake_run), \
                patch.object(collect.subprocess, "Popen", FakeLogcat), contextlib.redirect_stdout(io.StringIO()):
            collect.main()
        rows = [json.loads(line) for line in (out / "observations.jsonl").read_text().splitlines()]
        surface = [row for row in rows if row["type"] == "surface_poll"]
        assert any(row["phase"] == "load_star_first" and row["reason"] == "phase-begin" and row["supported"] for row in surface)
        assert any(row["phase"] == "load_star_first" and row["reason"] == "phase-end-final" for row in surface)
        assert all("raw" in row for row in surface if row["supported"])
        assert rows[-1]["finished"] is True and rows[-1]["gate_seen"] and rows[-1]["gate_start_seen"]
        assert all(not any(token in args for token in ["install", "uninstall", "input", "force-stop", "clear"]) for args in commands)
        missing_layer = True
        missing_gate = True
        out = Path(temp) / "missing"
        args[-3] = str(out)
        with patch.object(sys, "argv", args), patch.object(collect.subprocess, "run", fake_run), \
                patch.object(collect.subprocess, "Popen", FakeLogcat), contextlib.redirect_stdout(io.StringIO()):
            collect.main()
        rows = [json.loads(line) for line in (out / "observations.jsonl").read_text().splitlines()]
        assert any(row["type"] == "coverage_gap" for row in rows)
        assert any(row["type"] == "surface_poll" and not row["supported"] for row in rows)
        assert rows[-1]["finished"] is True and not rows[-1]["gate_seen"]
    print("ANDROID_RENDERER_COLLECTOR_TEST: pass")


if __name__ == "__main__":
    main()
