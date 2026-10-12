"""Actual Linux process supervision, priority and signal propagation acceptance."""

import json
import os
import signal
import subprocess
import sys
import time
from pathlib import Path

import pytest

pytestmark = pytest.mark.skipif(not sys.platform.startswith("linux"), reason="Requires actual Linux signals/nice")
PROBE = Path(__file__).with_name("service_worker_probe.py")


def wait_file(process, folder, name):
    deadline = time.monotonic() + 5
    while not (folder / name).exists() and process.poll() is None and time.monotonic() < deadline:
        time.sleep(0.01)
    assert (folder / name).exists(), f"Fixture did not reach {name}; supervisor={process.poll()}"
    return json.loads((folder / name).read_text(encoding="utf8"))


def launch(folder, mode):
    output = (folder / "supervisor.log").open("w", encoding="utf8")
    process = subprocess.Popen([sys.executable, str(PROBE), "supervise", str(folder), mode],
        stdout=output, stderr=output)
    return process, output


def assert_reaped(folder):
    for name in ("worker.ready", "product.ready", "descendant.ready"):
        if (folder / name).exists():
            pid = json.loads((folder / name).read_text(encoding="utf8"))["pid"]
            with pytest.raises(ProcessLookupError):
                os.kill(pid, 0)


def cleanup(process, output):
    if process.poll() is None:
        process.send_signal(signal.SIGTERM)
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=2)
    output.close()


@pytest.mark.parametrize("stop_signal", [signal.SIGTERM, signal.SIGINT])
def test_signals_reach_both_children_preserving_grace_and_priority(tmp_path, stop_signal):
    process, output = launch(tmp_path, "on")
    try:
        worker = wait_file(process, tmp_path, "worker.ready")
        product = wait_file(process, tmp_path, "product.ready")
        assert product["nice"] == 19 and worker["nice"] < product["nice"]
        assert worker["group"] == worker["pid"] and product["group"] == product["pid"]
        requested = time.monotonic()
        process.send_signal(stop_signal)
        assert process.wait(timeout=3) == 0
        for role in ("worker", "product"):
            delivered = json.loads((tmp_path / (role + ".signal")).read_text())
            assert delivered["signal"] == stop_signal
        assert time.monotonic() - requested >= 0.25
        assert json.loads((tmp_path / "supervisor.result").read_text())["handlers_restored"]
        assert_reaped(tmp_path)
    finally:
        cleanup(process, output)


def test_disabled_default_launches_only_competitive_worker(tmp_path):
    process, output = launch(tmp_path, "off")
    try:
        wait_file(process, tmp_path, "worker.ready")
        time.sleep(0.1)
        assert not (tmp_path / "product.ready").exists()
        process.send_signal(signal.SIGTERM)
        assert process.wait(timeout=3) == 0
        assert_reaped(tmp_path)
    finally:
        cleanup(process, output)


@pytest.mark.parametrize("mode", ["product_fail", "worker_fail", "product_exit_zero", "launch_failure", "priority_failure"])
def test_child_exit_or_launch_failure_cannot_leave_service_healthy(tmp_path, mode):
    process, output = launch(tmp_path, mode)
    try:
        wait_file(process, tmp_path, "worker.ready")
        assert process.wait(timeout=4) != 0
        assert (tmp_path / "worker.signal").exists() or mode == "worker_fail"
        if mode not in ("launch_failure", "priority_failure"):
            assert (tmp_path / "product.ready").exists()
        assert_reaped(tmp_path)
    finally:
        cleanup(process, output)


def test_stubborn_worker_is_force_stopped_with_bounded_nonzero_exit(tmp_path):
    process, output = launch(tmp_path, "timeout")
    try:
        wait_file(process, tmp_path, "worker.ready")
        wait_file(process, tmp_path, "product.ready")
        started = time.monotonic()
        process.send_signal(signal.SIGTERM)
        assert process.wait(timeout=3) != 0
        assert 0.5 <= time.monotonic() - started < 2.5
        assert_reaped(tmp_path)
    finally:
        cleanup(process, output)


def test_uncooperative_descendant_is_killed_and_reaped(tmp_path):
    process, output = launch(tmp_path, "orphan")
    try:
        wait_file(process, tmp_path, "worker.ready")
        wait_file(process, tmp_path, "product.ready")
        wait_file(process, tmp_path, "descendant.ready")
        process.send_signal(signal.SIGTERM)
        assert process.wait(timeout=3) != 0
        assert_reaped(tmp_path)
    finally:
        cleanup(process, output)
