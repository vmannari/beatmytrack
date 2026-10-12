"""Supervise competition and optional low-priority product work in one container."""

from __future__ import annotations

import logging
import os
import signal
import subprocess
import sys
import time

log = logging.getLogger("bmt.service_worker")


def _product_priority():
    # This supervisor is single-threaded; the pre-exec hook makes only this
    # syscall, before product code imports or starts database/CPU work.
    os.setpriority(os.PRIO_PROCESS, 0, 19)


def _spawn(role, command):
    options = {"start_new_session": os.name == "posix"}
    if role == "product" and sys.platform.startswith("linux"):
        options["preexec_fn"] = _product_priority
    return subprocess.Popen(command, **options)


def _adopt_descendants():
    if not sys.platform.startswith("linux") or os.getpid() == 1:
        return
    # PID 1 already adopts descendants. A standalone Linux supervisor must do
    # the same so a misbehaving child cannot leave an unreaped verifier behind.
    import ctypes

    library = ctypes.CDLL(None, use_errno=True)
    if library.prctl(36, 1, 0, 0, 0) != 0:  # Linux PR_SET_CHILD_SUBREAPER
        raise OSError(ctypes.get_errno(), "Cannot supervise descendant cleanup")


def _reap_adopted():
    if os.name != "posix":
        return False
    while True:
        try:
            pid, _status = os.waitpid(-1, os.WNOHANG)
        except ChildProcessError:
            return False
        if pid == 0:
            return True


def _signal_child(child, signum):
    if child.poll() is None:
        try:
            child.send_signal(signum)
        except ProcessLookupError:
            pass


def _kill_group(child):
    if os.name == "posix":
        try:
            os.killpg(child.pid, signal.SIGKILL)
            return True
        except ProcessLookupError:
            return False
    if child.poll() is None:
        child.kill()
        return True
    return False


def supervise(*, telemetry_enabled=False, shutdown_seconds=7.0, commands=None, child_factory=_spawn):
    """Fixed shipping roles; commands/factory injection is for process tests only.

    Normal exit requires a stop request, clean child exits and no forced cleanup.
    A daemon exiting by itself, including exit zero, stops its peer and fails the
    service so an unhealthy product process cannot hide behind worker readiness.
    """
    if not 0.1 <= shutdown_seconds <= 300:
        raise ValueError("Invalid bounded service shutdown budget")
    shipping = {
        "worker": (sys.executable, "-m", "bmt_backend.worker"),
        "product": (sys.executable, "-m", "bmt_backend.product_worker"),
    }
    selected = commands if commands is not None else shipping
    roles = ("worker", "product") if telemetry_enabled else ("worker",)
    children, previous = {}, {}
    requested_at, requested_signal, failed = None, None, False

    def stop(signum, _frame):
        nonlocal requested_at, requested_signal
        if requested_at is None:
            requested_at, requested_signal = time.monotonic(), signum

    _adopt_descendants()
    try:
        for signum in (signal.SIGTERM, signal.SIGINT):
            previous[signum] = signal.getsignal(signum)
            signal.signal(signum, stop)
        for role in roles:
            if requested_at is not None:
                break
            children[role] = child_factory(role, selected[role])
            log.info("service_child_started role=%s pid=%s", role, children[role].pid)
        while requested_at is None:
            for role, child in children.items():
                code = child.poll()
                if code is not None:
                    log.error("service_child_exited role=%s code=%s", role, code)
                    failed = True
                    requested_at, requested_signal = time.monotonic(), signal.SIGTERM
                    break
            if requested_at is None:
                time.sleep(0.05)
    except (OSError, KeyError, subprocess.SubprocessError):
        log.exception("service_child_launch_failed")
        failed = True
        requested_at, requested_signal = time.monotonic(), signal.SIGTERM
    finally:
        if requested_at is None:
            requested_at, requested_signal = time.monotonic(), signal.SIGTERM
        # Signal the child PID, not its whole group: the competitive worker owns
        # its verifier cancellation and retains its existing finish grace.
        for child in children.values():
            _signal_child(child, requested_signal)
        deadline = requested_at + shutdown_seconds
        while any(child.poll() is None for child in children.values()) and time.monotonic() < deadline:
            time.sleep(min(0.05, max(0, deadline - time.monotonic())))
        for child in children.values():
            if child.poll() is None:
                failed = _kill_group(child) or failed
        # Reap tracked children first; generic waitpid must not steal their exit
        # status and accidentally report a failed worker as a clean shutdown.
        for role, child in children.items():
            try:
                code = child.wait(timeout=1)
            except subprocess.TimeoutExpired:
                log.error("service_child_did_not_stop role=%s", role)
                failed = True
                continue
            if code != 0:
                failed = True
        _reap_adopted()
        for child in children.values():
            # A direct child can exit without cleaning up its own descendants.
            failed = _kill_group(child) or failed
        reaping_until = time.monotonic() + 0.5
        while _reap_adopted() and time.monotonic() < reaping_until:
            time.sleep(0.01)
        for signum, handler in previous.items():
            signal.signal(signum, handler)
    return 1 if failed else 0


def main():
    from .config import Settings

    settings = Settings.from_env()
    logging.basicConfig(level=logging.INFO)
    return supervise(telemetry_enabled=settings.telemetry_enabled,
        shutdown_seconds=settings.worker_shutdown_grace_seconds + 2)


if __name__ == "__main__":
    raise SystemExit(main())
