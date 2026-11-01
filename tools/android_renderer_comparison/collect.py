"""Read-only SurfaceFlinger/logcat collector for an already running probe.

Never installs, launches, stops, clears or injects input into any application.
Raw observations are retained; phase boundaries are not presumed to align
with Android's presentation clock.
"""
from __future__ import annotations

import argparse
import json
import queue
import re
import shlex
import subprocess
import threading
import time
from pathlib import Path

PACKAGES = {"org.beatmytrack.rendererprobe.gl20261031", "org.beatmytrack.rendererprobe.vk20261031"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--adb", required=True)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--package", required=True, choices=sorted(PACKAGES))
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--duration", type=int, default=900)
    args = parser.parse_args()
    if args.duration < 1 or args.duration > 1800:
        parser.error("duration must be 1..1800 seconds")
    args.out.mkdir(parents=True, exist_ok=False)
    prefix = [args.adb, "-s", args.serial]
    records = (args.out / "observations.jsonl").open("w", encoding="utf-8", buffering=1)

    def write(kind: str, **fields: object) -> None:
        records.write(json.dumps({"type": kind, "host_monotonic_ns": time.monotonic_ns(), **fields}) + "\n")

    def adb(*values: str) -> tuple[int, str, str]:
        try:
            result = subprocess.run(prefix + list(values), capture_output=True, text=True,
                                    encoding="utf-8", errors="replace", timeout=8)
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -1, "", "ADB command timed out"

    code, pids, error = adb("shell", "pidof", args.package)
    if code != 0 or len(pids.split()) != 1 or not pids.strip().isdigit():
        write("unavailable", reason="probe is not running as one PID", exit=code, stderr=error)
        raise SystemExit("Start the isolated probe separately before collecting; no device action was taken.")
    pid = pids.strip()

    def foreground() -> bool:
        code, out, err = adb("shell", "dumpsys", "activity", "activities")
        lines = [line.strip() for line in out.splitlines() if "topResumedActivity=" in line]
        write("foreground", exit=code, lines=lines, stderr=err)
        return code == 0 and len(lines) == 1 and args.package in lines[0]

    if not foreground():
        write("unavailable", reason="probe is not the sole top resumed activity")
        raise SystemExit("The isolated probe is not in the foreground; no device action was taken.")
    write("start", package=args.package, pid=pid,
          limitations=["capture begins after attach", "SurfaceFlinger ring may overwrite samples",
                       "phase-marker receipt and display timestamps have different clocks",
                       "maximum observed gap is a lower bound without boundary coverage",
                       "touch receipt is not physical input-to-photon latency"])
    logcat = subprocess.Popen(prefix + ["logcat", "--pid=" + pid, "-v", "raw", "-T", "1"],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                              encoding="utf-8", errors="replace", bufsize=1)
    lines: queue.Queue[str] = queue.Queue()
    def reader() -> None:
        assert logcat.stdout is not None
        for line in logcat.stdout:
            lines.put(line.rstrip("\r\n"))
    threading.Thread(target=reader, daemon=True).start()
    phase = "attach"
    layer = ""
    last_poll = None
    next_focus = 0.0
    started = time.monotonic()
    next_poll = started
    finished = False
    gate_seen = False
    gate_start_seen = False

    def poll(reason: str) -> None:
        nonlocal layer, last_poll
        if not layer:
            code, output, err = adb("shell", "dumpsys", "SurfaceFlinger", "--list")
            candidates = [item for item in output.splitlines()
                          if args.package in item and "SurfaceView" in item and "BLAST" in item]
            write("layer_search", exit=code, candidates=candidates, stderr=err)
            if candidates:
                layer = candidates[-1]
                decorated = re.match(r"RequestedLayerState\{(.+?) parentId=", layer)
                if decorated:
                    layer = decorated[1]
        began = time.monotonic_ns()
        gap = None if last_poll is None else (began - last_poll) / 1e6
        last_poll = began
        if not layer:
            write("surface_poll", phase=phase, reason=reason, supported=False, gap_ms=gap,
                  error="No matching SurfaceView/BLAST layer")
            return
        code, out, err = adb("shell", "dumpsys SurfaceFlinger --latency " + shlex.quote(layer))
        rows = [line for line in out.splitlines() if len(line.split()) == 3 and
                all(value.isdigit() for value in line.split())]
        write("surface_poll", phase=phase, reason=reason, supported=code == 0 and bool(rows),
              layer=layer, gap_ms=gap, exit=code, raw=out, stderr=err)

    try:
        while time.monotonic() - started < args.duration:
            while True:
                try:
                    line = lines.get_nowait()
                except queue.Empty:
                    break
                if "BMT_PERF_" in line:
                    write("probe_log", phase=phase, line=line)
                if "BMT_PERF_GATE_READY " in line:
                    gate_seen = True
                elif "BMT_PERF_GATE_START " in line:
                    gate_start_seen = True
                elif "BMT_PERF_BEGIN " in line:
                    if not gate_seen or not gate_start_seen:
                        write("coverage_gap", reason="collector did not observe both gate markers before phase begin")
                    if phase != "attach":
                        poll("previous-phase-final-at-next-begin")
                    phase = line.split("BMT_PERF_BEGIN ", 1)[1].strip()
                    poll("phase-begin")
                elif "BMT_PERF_CASE " in line:
                    poll("phase-end-final")
                    phase = "between"
                elif "BMT_PERF_FINISHED " in line:
                    poll("probe-finished-final")
                    finished = True
                    break
            if finished:
                break
            now = time.monotonic()
            if now >= next_focus:
                if not foreground():
                    write("stopped", reason="foreground changed; no device action taken")
                    break
                next_focus = now + 3.0
            if now >= next_poll:
                poll("periodic")
                next_poll = time.monotonic() + 0.4
            if logcat.poll() is not None and lines.empty():
                write("stopped", reason="logcat exited", exit=logcat.returncode)
                break
            time.sleep(0.05)
        else:
            poll("collector-timeout-final")
            write("stopped", reason="collector deadline")
    finally:
        logcat.terminate()
        try:
            _, stderr = logcat.communicate(timeout=5)
        except subprocess.TimeoutExpired:
            logcat.kill()
            _, stderr = logcat.communicate()
        write("end", finished=finished, gate_seen=gate_seen, gate_start_seen=gate_start_seen,
              logcat_stderr=stderr)
        records.close()


if __name__ == "__main__":
    main()
