"""Own one disposable PostgreSQL container for Studio checks and measurements."""
import json
import os
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = Path(__file__).resolve().parent


def main():
    name, label, password = "bmt-studio-perf-" + secrets.token_hex(4), secrets.token_hex(16), secrets.token_urlsafe(24)
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]

    def docker(*args):
        return subprocess.run(["wsl", "-d", "Ubuntu", "--", "docker", *args], capture_output=True, text=True, timeout=60)

    started = docker("run", "-d", "--rm", "--name", name, "--label", "bmt.task=" + label,
        "-p", f"127.0.0.1:{port}:5432", "-e", "POSTGRES_USER=studio_test", "-e", "POSTGRES_DB=studio_test",
        "-e", "POSTGRES_PASSWORD=" + password, "postgres:17")
    if started.returncode:
        raise RuntimeError("Could not start an owned disposable PostgreSQL container")
    try:
        for _attempt in range(40):
            if docker("exec", name, "pg_isready", "-U", "studio_test").returncode == 0:
                break
            time.sleep(.5)
        else:
            raise RuntimeError("Owned PostgreSQL did not become ready")
        env = dict(os.environ, PYTHONPATH=str(ROOT / "backend"), PYTHONUTF8="1",
            BMT_TEST_DATABASE_URL=f"postgresql+psycopg://studio_test:{password}@127.0.0.1:{port}/studio_test")
        tested = subprocess.run([sys.executable, "-m", "pytest",
            "backend/tests/test_studio_performance_postgres.py", "backend/tests/test_studio_platform_postgres.py",
            "backend/tests/test_admin.py", "-q", "--tb=short", "--junitxml=" + str(OUTPUT / "postgres.xml")],
            cwd=ROOT, env=env, capture_output=True, text=True, timeout=600)
        output = (tested.stdout + tested.stderr).replace(password, "[REDACTED]")
        (OUTPUT / "postgres.log").write_text(output, encoding="utf-8")
        print(output[-6500:])
        measured = subprocess.run([sys.executable, str(OUTPUT / "measure.py")], cwd=ROOT,
            env=env, capture_output=True, text=True, timeout=600)
        output = (measured.stdout + measured.stderr).replace(password, "[REDACTED]")
        (OUTPUT / "measure.log").write_text(output, encoding="utf-8")
        print(output[-3000:])
        return tested.returncode or measured.returncode
    finally:
        checked = docker("inspect", name, "--format", "{{json .Config.Labels}}")
        if checked.returncode == 0 and json.loads(checked.stdout).get("bmt.task") == label:
            removed = docker("stop", name).returncode == 0
            (OUTPUT / "postgres-cleanup.json").write_text(json.dumps({"owned_container_removed": removed}) + "\n")
            print("Owned PostgreSQL removed:", removed)
        else:
            raise RuntimeError("Container ownership changed; leaving it untouched")


if __name__ == "__main__":
    raise SystemExit(main())
