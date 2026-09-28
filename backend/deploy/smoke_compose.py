"""Exercise real PostgreSQL/API packaging and backup/restore in disposable projects.

Run on a Linux Docker host with the full production image and --full-image, or
build Dockerfile's python-runtime target as bmt-backend:deployment-test for an
infrastructure-only check. Neither mode exercises real Google sign-in or a NAS.
No existing project/volume is reused.
"""

from __future__ import annotations

import argparse
import json
import os
import secrets
import subprocess
import urllib.error
import urllib.request
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--full-image",
        action="store_true",
        help="Use bmt-backend:local and exercise the real Linux game flow",
    )
    args = parser.parse_args()
    repository = Path(__file__).resolve().parents[2]
    deployment = repository / "backend" / "deploy"
    project = "bmt-ops-check-" + secrets.token_hex(4)
    restored_project = project + "-restore"
    # Keep the generated configuration/backup under ignored build/ for audit/retry.
    evidence = repository / "build" / "backend-operations" / project
    evidence.mkdir(parents=True)
    config = evidence / ".env"
    image_name = "bmt-backend:local" if args.full_image else "bmt-backend:deployment-test"
    development_key = secrets.token_hex(32)
    config.write_text(
        f"COMPOSE_PROJECT_NAME={project}\n"
        f"POSTGRES_PASSWORD={secrets.token_hex(32)}\nBMT_DB_PASSWORD={secrets.token_hex(32)}\n"
        "BMT_PUBLIC_BASE_URL=http://localhost:18087\nBMT_PORT=18087\n"
        f"BMT_GOOGLE_CLIENT_IDS=\nBMT_IMAGE={image_name}\n"
        f"TEST_DEV_AUTH_KEY={development_key}\n"
        "GODOT_SHA256=smoke-test-reuses-prebuilt-image-no-build-attempted\n",
        encoding="utf-8",
    )
    config.chmod(0o600)
    override = evidence / "override.yaml"
    override_content = (
        'services:\n  api:\n    command: [uvicorn, "bmt_backend.app:create_app", --factory, '
        '--host, "0.0.0.0", --port, "8080", --no-proxy-headers, --no-access-log]\n'
    )
    if args.full_image:
        override_content += (
            "    environment:\n      BMT_ENVIRONMENT: development\n"
            '      BMT_DEV_AUTH_ENABLED: "true"\n      BMT_DEV_AUTH_KEY: ${TEST_DEV_AUTH_KEY}\n'
        )
    override.write_text(override_content, encoding="utf-8")
    base = ["docker", "compose", "--env-file", str(config), "-f", str(deployment / "compose.yaml")]

    def run(command, *, data=None, expected=0):
        process = subprocess.run(
            command,
            input=data,
            capture_output=True,
            check=False,
            env={**os.environ, "BMT_ENV_FILE": str(config)},
        )
        if process.returncode != expected:
            raise RuntimeError(
                f"Command failed ({process.returncode}): {command}\n"
                + process.stdout.decode(errors="replace")
                + process.stderr.decode(errors="replace")
            )
        return process.stdout

    completed = []
    try:
        run(base + ["config", "--quiet"])
        run(base + ["-f", str(override), "up", "--no-build", "-d", "--wait"])
        for endpoint in ("healthz", "readyz"):
            with urllib.request.urlopen(f"http://127.0.0.1:18087/{endpoint}", timeout=10) as response:
                assert response.status == 200
        completed.append("Compose config, nonroot API readiness, separate worker and migration passed")
        if args.full_image:
            from smoke_http import verify_http_flow

            completed.extend(verify_http_flow(repository, development_key))
        else:
            try:
                urllib.request.urlopen("http://127.0.0.1:18087/v1/manifest", timeout=10)
                raise AssertionError("Python-only image unexpectedly supplied a canonical manifest")
            except urllib.error.HTTPError as unavailable:
                assert unavailable.code == 503
            completed.append("Python-only image fails closed for missing canonical engine")
        # App owns its schema but cannot administer the server.
        privileges = run(
            base
            + [
                "exec",
                "-T",
                "db",
                "psql",
                "-U",
                "postgres",
                "-d",
                "bmt",
                "-Atc",
                "SELECT rolsuper,rolcreatedb,rolcreaterole FROM pg_roles WHERE rolname='bmt'",
            ]
        )
        assert privileges.strip() == b"f|f|f", privileges
        completed.append("Runtime PostgreSQL role is nonsuperuser without database/role creation")
        run(
            base
            + [
                "exec",
                "-T",
                "db",
                "psql",
                "-U",
                "bmt",
                "-d",
                "bmt",
                "-v",
                "ON_ERROR_STOP=1",
                "-c",
                "CREATE TABLE backup_probe (id integer PRIMARY KEY, value text); INSERT INTO backup_probe VALUES (1,'restore-ok')",
            ]
        )
        digest = (
            run(
                base
                + [
                    "exec",
                    "-T",
                    "api",
                    "python",
                    "-c",
                    "from bmt_backend.storage import LocalBlobStore; print(LocalBlobStore('/var/lib/bmt/objects').put_json({'backup':'roundtrip'}))",
                ]
            )
            .decode()
            .strip()
        )
        backup = evidence / "snapshot"
        run(["sh", str(deployment / "backup.sh"), str(backup)])
        assert (backup / "COMPLETE").is_file()
        run(["sh", str(deployment / "restore.sh"), str(backup), restored_project])
        target = base + ["-p", restored_project]
        value = run(
            target
            + [
                "exec",
                "-T",
                "db",
                "psql",
                "-U",
                "bmt",
                "-d",
                "bmt",
                "-Atc",
                "SELECT value FROM backup_probe WHERE id=1",
            ]
        )
        assert value.strip() == b"restore-ok"
        body = run(
            target
            + [
                "run",
                "--rm",
                "--no-deps",
                "-T",
                "--entrypoint",
                "python",
                "api",
                "-c",
                f"from bmt_backend.storage import LocalBlobStore; import json; print(json.dumps(LocalBlobStore('/var/lib/bmt/objects').get_json('{digest}')))",
            ]
        )
        assert json.loads(body) == {"backup": "roundtrip"}
        if args.full_image:
            counts = run(
                target
                + [
                    "exec",
                    "-T",
                    "db",
                    "psql",
                    "-U",
                    "bmt",
                    "-d",
                    "bmt",
                    "-Atc",
                    "SELECT (SELECT count(*) FROM players),(SELECT count(*) FROM personal_bests),(SELECT count(*) FROM ratings)",
                ]
            )
            assert counts.strip() == b"2|2|1", counts
        assert (
            not run(target + ["ps", "--status", "running", "--services"]).decode().strip().replace("db", "")
        )
        completed.append(
            "Quiesced backup restored DB and hashed object into isolated empty project; writers remained stopped"
        )
        run(["sh", str(deployment / "restore.sh"), str(backup), restored_project], expected=1)
        run(["sh", str(deployment / "restore.sh"), str(backup), project], expected=1)
        completed.append("Restore refused occupied target and original source project")
        with (backup / "objects.tar").open("ab") as output:
            output.write(b"tampered")
        run(["sh", str(deployment / "restore.sh"), str(backup), restored_project + "-corrupt"], expected=1)
        completed.append("Checksum mismatch refused before target creation")
        # Recover evidence archive to original bytes; checksum can be independently checked.
        with (backup / "objects.tar").open("r+b") as output:
            output.truncate((backup / "objects.tar").stat().st_size - len(b"tampered"))
        report = {
            "project": project,
            "checks": completed,
            "scope": "Full Linux image, canonical replay and PostgreSQL; development identity, no real Google token"
            if args.full_image
            else "Python base image / PostgreSQL only; no Linux Godot",
            "passed": True,
        }
        (evidence / "result.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2))
    finally:
        # These names were generated for this test. Existing host deployments are untouched.
        for name in (project, restored_project):
            subprocess.run(
                base + ["-p", name, "down", "--volumes", "--remove-orphans"], capture_output=True, check=False
            )


if __name__ == "__main__":
    main()
