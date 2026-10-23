"""Real Linux children, signal delivery, failure propagation and reaping."""
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = next(parent for parent in Path(__file__).resolve().parents if (parent / "backend/bmt_backend").is_dir())
PROBE = ROOT / "backend/tests/service_worker_probe.py"
results = []


def wait_file(process, folder, name):
    deadline = time.monotonic() + 5
    while not (folder / name).exists() and process.poll() is None and time.monotonic() < deadline:
        time.sleep(0.01)
    assert (folder / name).exists(), (name, process.poll(), (folder / "output.log").read_text())
    return json.loads((folder / name).read_text())


for mode, stop_signal in [("on", signal.SIGTERM), ("on", signal.SIGINT), ("off", signal.SIGTERM)] + [
        (mode, None) for mode in ["product_fail", "worker_fail", "publication_fail", "publication_exit_zero",
                                 "product_exit_zero", "launch_failure", "priority_failure", "timeout", "orphan"]]:
    with tempfile.TemporaryDirectory(prefix="bmt-publication-process-") as temporary:
        folder = Path(temporary)
        with (folder / "output.log").open("w") as output:
            process = subprocess.Popen([sys.executable, str(PROBE), "supervise", temporary, mode],
                stdout=output, stderr=output)
            try:
                worker = wait_file(process, folder, "worker.ready")
                if mode in ("on", "off", "timeout", "orphan"):
                    publication = wait_file(process, folder, "publication.ready")
                    assert publication["group"] == publication["pid"]
                    assert publication["nice"] == worker["nice"]
                    if mode != "off":
                        product = wait_file(process, folder, "product.ready")
                        assert product["nice"] == 19 and worker["nice"] < product["nice"]
                    else:
                        assert not (folder / "product.ready").exists()
                    if mode == "orphan":
                        wait_file(process, folder, "descendant.ready")
                    process.send_signal(stop_signal or signal.SIGTERM)
                code = process.wait(timeout=5)
                assert code == (0 if stop_signal else 1), (mode, code, (folder / "output.log").read_text())
                if stop_signal:
                    for role in ["worker", "publication"] + (["product"] if mode == "on" else []):
                        assert json.loads((folder / (role + ".signal")).read_text())["signal"] == stop_signal
                assert json.loads((folder / "supervisor.result").read_text())["handlers_restored"]
                for role in ["worker", "publication", "product", "descendant"]:
                    ready = folder / (role + ".ready")
                    if ready.exists():
                        pid = json.loads(ready.read_text())["pid"]
                        try:
                            os.kill(pid, 0)
                        except ProcessLookupError:
                            pass
                        else:
                            raise AssertionError((mode, "unreaped", role, pid))
                results.append({"mode": mode, "signal": stop_signal, "exit_code": code, "passed": True})
            finally:
                if process.poll() is None:
                    process.send_signal(signal.SIGTERM)
                    process.wait(timeout=5)
report = {"passed": len(results), "cases": results}
(ROOT / "docs/evidence/publication-speed-2026-10-18/linux-processes.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report))
