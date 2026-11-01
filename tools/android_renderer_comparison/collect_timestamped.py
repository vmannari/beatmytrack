"""Opt-in future collector with PID-scoped monotonic logcat metadata.

This wrapper delegates to the same read-only collector and changes only its
logcat output format. It does not validate device clocks or certify phase-to-
presentation alignment. It never installs, starts, stops or controls an app.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import collect


def timestamped_logcat_command(command: list[str]) -> list[str]:
    """Change only the collector's known PID-scoped raw logcat invocation."""
    result = list(command)
    if "logcat" not in result:
        return result
    index = result.index("logcat")
    tail = result[index + 1:]
    if not any(item.startswith("--pid=") for item in tail) or tail.count("-v") != 1:
        raise ValueError("Unexpected logcat command; refusing to change its format")
    position = result.index("-v", index + 1)
    if position + 1 >= len(result) or result[position + 1] != "raw":
        raise ValueError("Expected exactly the known raw logcat format")
    return result[:position] + ["-v", "threadtime", "-v", "monotonic", "-v", "usec"] + result[position + 2:]


def main() -> None:
    # Delegate validation and package allowlisting to the unmodified collector.
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--out", type=Path, required=True)
    args, _ = parser.parse_known_args()
    original = subprocess.Popen

    def wrapped(command, *positional, **keyword):
        if isinstance(command, (list, tuple)):
            command = timestamped_logcat_command(list(command))
        return original(command, *positional, **keyword)

    subprocess.Popen = wrapped
    try:
        collect.main()
    finally:
        subprocess.Popen = original
    receipt = {"logcat_format":["threadtime", "monotonic", "usec"],
               "clock_alignment_verified":False, "timestamps_verified":False,
               "claim":"format requested; actual output, clock domain, conversion and phase boundaries require independent validation",
               "device_actions":"same read-only pid, foreground, logcat and SurfaceFlinger calls as collect.py",
               "analysis":"never infer a phase maximum from timestamp metadata without verified clocks and complete presentation coverage"}
    # collect.py refuses an existing output directory. Never replace a receipt.
    with (args.out / "timestamped-format.json").open("x", encoding="utf-8") as output:
        json.dump(receipt, output, indent=2)


if __name__ == "__main__":
    main()
