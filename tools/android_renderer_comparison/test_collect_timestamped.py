"""Offline-only checks of opt-in timestamp formatting and marker handling."""
import base64
import contextlib
import io
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import analyze_capture
import collect
import collect_timestamped
import test_collect


class TimestampedTests(unittest.TestCase):
    def test_command_fails_closed(self):
        command = ["adb", "-s", "test", "logcat", "--pid=4321", "-v", "raw"]
        self.assertEqual(collect_timestamped.timestamped_logcat_command(command),
                         ["adb", "-s", "test", "logcat", "--pid=4321", "-v", "threadtime",
                          "-v", "monotonic", "-v", "usec"])
        self.assertEqual(collect_timestamped.timestamped_logcat_command(["adb", "shell", "pidof"]),
                         ["adb", "shell", "pidof"])
        with self.assertRaises(ValueError):
            collect_timestamped.timestamped_logcat_command(["adb", "logcat", "-v", "raw"])
        with self.assertRaises(ValueError):
            collect_timestamped.timestamped_logcat_command(["adb", "logcat", "--pid=4321", "-v", "time"])

    def test_prefixed_output_through_collector(self):
        report = {"renderer":"gl_compatibility", "finished":True, "expected_cases":1,
                  "cases":[{"phase":"load_star_first", "frames":1}], "errors":[]}
        encoded = base64.b64encode(json.dumps(report).encode()).decode()
        lines = ["BMT_PERF_GATE_READY renderer=gl_compatibility", "BMT_PERF_GATE_START ticks_us=1000",
                 "BMT_PERF_BEGIN load_star_first", 'BMT_PERF_CASE {"phase":"load_star_first"}',
                 "BMT_PERF_CHUNK 0/1 " + encoded, "BMT_PERF_FINISHED 0"]

        class FakeLogcat(test_collect.FakeLogcat):
            def __init__(self, args, **kwargs):
                assert args[args.index("-v"):args.index("-v")+6] == ["-v", "threadtime", "-v", "monotonic", "-v", "usec"]
                self.stdout = io.StringIO("".join(f"  12345.{i:06}  4321  4322 I Godot : {line}\n"
                                                  for i, line in enumerate(lines)))
                self.returncode = None

        folder = Path("build/android-renderer-comparison-tests")
        folder.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=folder) as temp:
            out = Path(temp)/"capture"
            argv = ["collect_timestamped.py", "--adb", "fake-adb", "--serial", "test", "--package",
                    test_collect.PACKAGE, "--out", str(out), "--duration", "5"]
            with patch.object(sys, "argv", argv), patch.object(subprocess, "run", test_collect.fake_run), \
                 patch.object(subprocess, "Popen", FakeLogcat), contextlib.redirect_stdout(io.StringIO()):
                collect_timestamped.main()
                self.assertIs(subprocess.Popen, FakeLogcat)
            rows = [json.loads(line) for line in (out/"observations.jsonl").read_text().splitlines()]
            result = analyze_capture.analyze(rows)
            self.assertEqual(result["phase_begin_markers"], ["load_star_first"])
            self.assertEqual(result["report"], report)
            self.assertTrue(rows[-1]["finished"] and rows[-1]["gate_seen"] and rows[-1]["gate_start_seen"])
            markers = result["timestamped_logcat"]["recognized_markers"]
            self.assertEqual([m["kind"] for m in markers], ["GATE_READY", "GATE_START", "BEGIN", "CASE", "FINISHED"])
            self.assertEqual(markers[2]["timestamp_us"], 12345000002)
            self.assertEqual(markers[2]["pid"], 4321)
            self.assertEqual(result["timestamped_logcat"]["markers_with_unexpected_pid"], 0)
            self.assertFalse(result["timestamped_logcat"]["clock_alignment_verified"])
            receipt = json.loads((out/"timestamped-format.json").read_text())
            self.assertFalse(receipt["timestamps_verified"])
            self.assertFalse(receipt["clock_alignment_verified"])


if __name__ == "__main__":
    unittest.main()
