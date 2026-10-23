"""Disposable process fixture; accepts only a test database supplied by pytest."""

import json
import os
import sys
from pathlib import Path

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.publication_worker import process_job
from bmt_backend.worker_lifecycle import run_worker

if __name__ == "__main__":
    folder = Path(sys.argv[1])
    config = json.loads((folder / "worker.json").read_text())
    assert config["environment"] == "test" and config["database_url"].startswith("sqlite:///")
    app = create_app(Settings(**config))

    def job(application):
        if (folder / "stop").exists():
            application.state.worker_control.request_stop()
            return False
        result = process_job(application)
        if not (folder / "ready").exists():
            (folder / "ready").write_text(json.dumps({"worker_pid": os.getpid(),
                "engine_pid": application.state.verifier.engine_pid}))
        return result

    run_worker(app, job, idle_seconds=0.25)
