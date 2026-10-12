"""Run support/commerce checks in an owned disposable PostgreSQL container."""

import json
import os
import secrets
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    config = ROOT / ".tools/gcp-staging/config.json"
    docker = json.loads(config.read_text())["docker"] if config.is_file() else ["docker"]
    name = "bmt-admin-support-pg-" + secrets.token_hex(4)
    label = "admin-support-" + secrets.token_hex(8)
    password = secrets.token_urlsafe(24)
    port = 25447

    def call(*args):
        return subprocess.run([*docker, *args], capture_output=True, text=True, check=False)

    started = call("run", "-d", "--rm", "--name", name, "--label", "bmt.task=" + label,
        "-p", f"127.0.0.1:{port}:5432", "-e", "POSTGRES_USER=admin_support", "-e",
        "POSTGRES_DB=admin_support", "-e", "POSTGRES_PASSWORD=" + password, "postgres:17")
    if started.returncode:
        raise RuntimeError("Owned PostgreSQL could not start; no existing service was replaced")
    try:
        for _attempt in range(30):
            if call("exec", name, "pg_isready", "-U", "admin_support").returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("Owned database did not become ready")
        env = dict(os.environ)
        env["BMT_TEST_DATABASE_URL"] = f"postgresql+psycopg://admin_support:{password}@127.0.0.1:{port}/admin_support"
        command = [sys.executable, "-m", "pytest", "tests/test_admin_support.py", "tests/test_admin.py",
            "tests/test_store_admin.py", "tests/test_commerce.py", "tests/test_resumes.py",
            "-q", "--disable-warnings", "--tb=short"]
        tested = subprocess.run(command, cwd=ROOT / "backend", env=env,
            capture_output=True, text=True, check=False)
        output = ROOT / "docs/evidence/admin-support-2026-10-08/postgres-final.log"
        output.write_text(tested.stdout + tested.stderr, encoding="utf-8")
        print(tested.stdout[-5000:])
    finally:
        checked = call("inspect", name, "--format", "{{json .Config.Labels}}")
        if checked.returncode == 0 and json.loads(checked.stdout).get("bmt.task") == label:
            removed = call("stop", name)
            print("Owned PostgreSQL removed:", removed.returncode == 0)
        else:
            raise RuntimeError("Database ownership changed; leaving it untouched")
    return tested.returncode


if __name__ == "__main__":
    raise SystemExit(main())
