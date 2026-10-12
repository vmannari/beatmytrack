"""Telemetry/product regression against an owned disposable PostgreSQL database."""
import argparse
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
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--focused", action="store_true", help="Run only PostgreSQL-specific product cases")
    args = parser.parse_args()
    config = ROOT / ".tools/gcp-staging/config.json"
    docker = json.loads(config.read_text())["docker"] if config.is_file() else ["docker"]
    name = "bmt-product-pg-" + secrets.token_hex(4)
    label = "product-analysis-" + secrets.token_hex(8)
    password = secrets.token_urlsafe(24)
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]

    def call(*args):
        return subprocess.run([*docker, *args], capture_output=True, text=True, timeout=30, check=False)

    started = call("run", "-d", "--rm", "--name", name, "--label", "bmt.task=" + label,
        "-p", f"127.0.0.1:{port}:5432", "-e", "POSTGRES_USER=product_test", "-e",
        "POSTGRES_DB=product_test", "-e", "POSTGRES_PASSWORD=" + password, "postgres:17")
    if started.returncode:
        raise RuntimeError("Owned test DB could not start; no existing service was replaced")
    try:
        for _attempt in range(30):
            if call("exec", name, "pg_isready", "-U", "product_test").returncode == 0:
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("Owned DB did not become ready")
        env = dict(os.environ)
        env["BMT_TEST_DATABASE_URL"] = f"postgresql+psycopg://product_test:{password}@127.0.0.1:{port}/product_test"
        selected = ["tests/test_product_analytics.py", "tests/test_product_domain_events.py",
                    "tests/test_admin.py", "tests/test_admin_support.py", "tests/test_studio.py"]
        selection = ["tests/test_product_analytics.py", "tests/test_product_domain_events.py", "-k", "postgres"] if args.focused else selected
        result = subprocess.run([sys.executable, "-m", "pytest", *selection, "-q", "--tb=short"],
            cwd=ROOT / "backend", env=env, capture_output=True, text=True, check=False)
        output = (result.stdout + result.stderr).replace(password, "[REDACTED]")
        evidence = ROOT / "docs/evidence/telemetry-analysis-2026-10-11"
        evidence.mkdir(parents=True, exist_ok=True)
        log_name = "postgres-focused-tests.log" if args.focused else "postgres-tests.log"
        (evidence / log_name).write_text(output, encoding="utf-8")
        print(output[-6000:])
        benchmark = ROOT / "scripts/benchmark_product_analytics.py"
        if result.returncode == 0 and benchmark.is_file():
            profiled = subprocess.run([sys.executable, str(benchmark), "--postgres"], cwd=ROOT,
                env=env, capture_output=True, text=True, check=False)
            profiled_output = (profiled.stdout + profiled.stderr).replace(password, "[REDACTED]")
            (evidence / "postgres-benchmark.log").write_text(profiled_output, encoding="utf-8")
            print(profiled_output[-6000:])
            returncode = profiled.returncode
        else:
            returncode = result.returncode
    finally:
        checked = call("inspect", name, "--format", "{{json .Config.Labels}}")
        if checked.returncode == 0 and json.loads(checked.stdout).get("bmt.task") == label:
            stopped = call("stop", name)
            print("Owned PostgreSQL removed:", stopped.returncode == 0)
        else:
            raise RuntimeError("Test DB ownership changed; leaving it untouched")
    return returncode


if __name__ == "__main__":
    raise SystemExit(main())
