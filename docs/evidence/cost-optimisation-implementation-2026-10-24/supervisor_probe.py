"""Real Linux process priority, optional-role supervision and graceful signals."""
import json
import os
import signal
import sys
import tempfile
import threading
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "backend"))
from bmt_backend.service_worker import supervise

ROLES = ("worker", "publication", "discovery", "product", "ranking", "packing")


def child(folder, role):
    stopped = threading.Event()
    def stop(signum, _frame):
        (folder / (role+".signal")).write_text(str(signum))
        stopped.set()
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    (folder / (role+".ready")).write_text(json.dumps({"pid": os.getpid(), "nice": os.getpriority(os.PRIO_PROCESS, 0)}))
    stopped.wait(10)


def main():
    if len(sys.argv) > 1:
        child(Path(sys.argv[1]), sys.argv[2])
        return
    with tempfile.TemporaryDirectory(prefix="bmt-cost-supervisor-") as directory:
        folder = Path(directory)
        errors = []
        def request_stop():
            deadline = time.monotonic()+6
            while not all((folder / (role+".ready")).exists() for role in ROLES):
                if time.monotonic() > deadline:
                    errors.append("Children did not start within six seconds")
                    break
                time.sleep(.01)
            os.kill(os.getpid(), signal.SIGTERM)
        thread = threading.Thread(target=request_stop)
        thread.start()
        code = supervise(telemetry_enabled=True, ranking_enabled=True, packing_enabled=True, shutdown_seconds=3,
            commands={role: (sys.executable, str(Path(__file__).resolve()), directory, role) for role in ROLES})
        thread.join()
        assert not errors, errors
        assert code == 0, code
        ready = {role: json.loads((folder / (role+".ready")).read_text()) for role in ROLES}
        for role in ROLES:
            assert (folder / (role+".signal")).read_text() == str(signal.SIGTERM)
            try:
                os.kill(ready[role]["pid"], 0)
            except ProcessLookupError:
                pass
            else:
                raise AssertionError("Child was not reaped: "+role)
        assert ready["packing"]["nice"] == ready["ranking"]["nice"] == ready["product"]["nice"] == 19
        assert ready["worker"]["nice"] < 19
        result = {"passed": True, "roles": list(ROLES), "nice": {role: row["nice"] for role, row in ready.items()},
                  "all_signalled_and_reaped": True, "scope": "WSL Linux processes only; no database or cloud workload"}
        (HERE / "linux-supervisor.json").write_text(json.dumps(result, indent=2)+"\n")
        print(json.dumps(result))


if __name__ == "__main__":
    main()
