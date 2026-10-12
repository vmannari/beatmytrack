"""Owned subprocess fixture; never connects to a backend or verifier."""

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

from bmt_backend.service_worker import _spawn, supervise


def write(folder, name, value):
    (folder / name).write_text(json.dumps(value), encoding="utf8")


def child(folder, role, mode):
    stop_at = None

    def stopped(signum, _frame):
        nonlocal stop_at
        write(folder, role + ".signal", {"signal": signum, "at": time.monotonic()})
        if mode not in ("stubborn", "grandchild"):
            stop_at = time.monotonic()

    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, stopped)
    if mode == "orphan":
        subprocess.Popen([sys.executable, __file__, "child", str(folder), "descendant", "grandchild"])
    write(folder, role + ".ready", {"pid": os.getpid(), "group": os.getpgrp(),
        "nice": os.getpriority(os.PRIO_PROCESS, 0)})
    if mode in ("fail", "exit_zero"):
        time.sleep(0.15)
        return 17 if mode == "fail" else 0
    while stop_at is None:
        time.sleep(0.01)
    # Model the existing competitive worker's bounded finish grace.
    if role == "worker":
        time.sleep(0.25)
    write(folder, role + ".stopped", {"at": time.monotonic()})
    return 0


def supervisor(folder, mode):
    worker_mode = "fail" if mode == "worker_fail" else "stubborn" if mode == "timeout" else "orphan" if mode == "orphan" else "normal"
    product_mode = "fail" if mode == "product_fail" else "exit_zero" if mode == "product_exit_zero" else "normal"
    commands = {"worker": (sys.executable, __file__, "child", str(folder), "worker", worker_mode),
        "product": (sys.executable, __file__, "child", str(folder), "product", product_mode)}

    def factory(role, command):
        if mode in ("launch_failure", "priority_failure") and role == "product":
            deadline = time.monotonic() + 2
            while not (folder / "worker.ready").exists() and time.monotonic() < deadline:
                time.sleep(0.01)
            if mode == "priority_failure":
                raise subprocess.SubprocessError("Injected pre-exec priority failure")
            raise OSError("Injected launch failure")
        return _spawn(role, command)

    previous = {signum: signal.getsignal(signum) for signum in (signal.SIGTERM, signal.SIGINT)}
    options = {"shutdown_seconds": 0.6, "commands": commands, "child_factory": factory}
    if mode != "off":
        options["telemetry_enabled"] = True
    result = supervise(**options)
    write(folder, "supervisor.result", {"code": result,
        "handlers_restored": all(signal.getsignal(signum) == value for signum, value in previous.items())})
    return result


if __name__ == "__main__":
    operation, location, *args = sys.argv[1:]
    directory = Path(location)
    directory.mkdir(parents=True, exist_ok=True)
    raise SystemExit(child(directory, *args) if operation == "child" else supervisor(directory, args[0]))
