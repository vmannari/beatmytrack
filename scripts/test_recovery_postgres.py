"""Run recovery/auth regressions with a task-owned disposable PostgreSQL 17."""
import json
import os
import secrets
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    config = ROOT / ".tools/gcp-staging/config.json"
    docker = json.loads(config.read_text())["docker"] if config.is_file() else ["docker"]
    name = "bmt-recovery-pg-" + secrets.token_hex(4)
    label = "recovery-" + secrets.token_hex(8)
    password = secrets.token_urlsafe(24)
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]

    def call(*arguments):
        return subprocess.run([*docker, *arguments], capture_output=True, text=True, timeout=30, check=False)

    if call("image", "inspect", "postgres:17").returncode:
        raise RuntimeError("Existing PostgreSQL 17 image unavailable; no image pulled")
    started = call("run", "-d", "--rm", "--name", name, "--label", "bmt.task=" + label,
                   "-p", f"127.0.0.1:{port}:5432", "-e", "POSTGRES_USER=recovery_test",
                   "-e", "POSTGRES_DB=recovery_test", "-e", "POSTGRES_PASSWORD=" + password, "postgres:17")
    if started.returncode:
        raise RuntimeError("Owned PostgreSQL could not start; no existing service changed")
    result = None
    try:
        for _ in range(30):
            if call("exec", name, "pg_isready", "-U", "recovery_test").returncode == 0:
                break
            time.sleep(.5)
        else:
            raise RuntimeError("Owned PostgreSQL did not become ready")
        env = dict(os.environ)
        env["BMT_TEST_DATABASE_URL"] = f"postgresql+psycopg://recovery_test:{password}@127.0.0.1:{port}/recovery_test"
        result = subprocess.run(
            [sys.executable, "-m", "pytest", "tests/test_resume_recovery_wire.py",
             "tests/test_exception_recovery.py", "tests/test_auth.py", "-q", "--tb=short", "--show-capture=no"],
            cwd=ROOT / "backend", env=env, capture_output=True, text=True, check=False, timeout=180,
        )
        output = (result.stdout + result.stderr).replace(password, "[REDACTED]")
        evidence = ROOT / "docs/evidence/recovery-rate-limit-2026-10-12"
        evidence.mkdir(parents=True, exist_ok=True)
        (evidence / "backend-regression.log").write_text(output, encoding="utf-8")
        print(output[-6000:])
    finally:
        owned = call("inspect", name, "--format", "{{json .Config.Labels}}")
        if owned.returncode != 0 or json.loads(owned.stdout).get("bmt.task") != label:
            raise RuntimeError("Owned database label changed; leaving it untouched")
        if call("stop", name).returncode:
            raise RuntimeError("Owned database cleanup failed")
        print("Owned PostgreSQL removed")
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())
