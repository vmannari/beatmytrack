"""Start the isolated PC backend and configure normal Godot/editor launches."""

import argparse
import configparser
import hashlib
import json
import os
import secrets
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENV_FILE = ROOT / ".tools" / "bmt-pc.env"
URL = "http://127.0.0.1:18181"


def local_configuration():
    ENV_FILE.parent.mkdir(exist_ok=True)
    if not ENV_FILE.exists():
        with ENV_FILE.open("x", encoding="utf-8") as output:
            output.write(f"BMT_DB_PASSWORD={secrets.token_hex(32)}\n")
            output.write(f"BMT_DEV_AUTH_KEY={secrets.token_urlsafe(32)}\n")
            output.write("BMT_GOOGLE_CLIENT_IDS=\nBMT_GOOGLE_WEB_CLIENT_ID=\n")
    config = dict(
        line.split("=", 1)
        for line in ENV_FILE.read_text().splitlines()
        if "=" in line and not line.startswith("#")
    )
    if len(config.get("BMT_DEV_AUTH_KEY", "")) < 32:
        raise RuntimeError("Invalid private development configuration")
    for name in ("BMT_ADMIN_OWNER_KEY", "BMT_ADMIN_ANALYST_KEY"):
        if not config.get(name):
            config[name] = secrets.token_urlsafe(32)
            with ENV_FILE.open("a", encoding="utf-8") as output:
                output.write(f"\n{name}={config[name]}\n")
    return config


def configure_game(config):
    target = Path(os.environ["APPDATA"]) / "Circuit01Lab" / "backend.cfg"
    existing = configparser.ConfigParser(interpolation=None)
    if target.exists():
        existing.read(target, encoding="utf-8")
        current = existing.get("backend", "url", fallback="").strip('"')
        if current not in ("", URL, "http://127.0.0.1:8080", "http://localhost:8080"):
            raise RuntimeError(
                "Game already targets another backend; local configuration was not overwritten"
            )
    if not existing.has_section("backend"):
        existing.add_section("backend")
    existing.set("backend", "url", '"' + URL + '"')
    existing.set("backend", "development_key", '"' + config["BMT_DEV_AUTH_KEY"] + '"')
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix(".cfg.tmp")
    with temporary.open("w", encoding="utf-8") as output:
        existing.write(output)
    temporary.replace(target)


def enable_test_drivers(config):
    """Persist the explicit local opt-in without changing private credentials."""
    lines = ENV_FILE.read_text(encoding="utf-8").splitlines()
    lines = [line for line in lines if not line.startswith("BMT_TEST_DRIVERS_ENABLED=")]
    lines.append("BMT_TEST_DRIVERS_ENABLED=true")
    temporary = ENV_FILE.with_suffix(".env.tmp")
    temporary.write_text("\n".join(lines) + "\n", encoding="utf-8")
    temporary.replace(ENV_FILE)
    config["BMT_TEST_DRIVERS_ENABLED"] = "true"


def backup_local_data(command):
    """Quiesce the PC writers and save logical data before the additive migration."""
    running = subprocess.run(
        [*command, "ps", "--status", "running", "--services"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    ).stdout.split()
    if "db" not in running:
        return None
    subprocess.run([*command, "stop", "api", "worker"], cwd=ROOT, check=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    destination = ROOT / "build" / "pc-backups" / stamp
    destination.mkdir(parents=True, mode=0o700)
    commands = {
        "database.dump": [
            *command,
            "exec",
            "-T",
            "db",
            "pg_dump",
            "-U",
            "bmt",
            "-d",
            "bmt",
            "--format=custom",
            "--no-owner",
            "--no-privileges",
        ],
        "objects.tar": [
            *command,
            "run",
            "--rm",
            "--no-deps",
            "-T",
            "--entrypoint",
            "python",
            "api",
            "/app/deploy/object_archive.py",
            "archive",
        ],
    }
    hashes = {}
    for name, arguments in commands.items():
        with (destination / name).open("xb") as output:
            subprocess.run(arguments, cwd=ROOT, stdout=output, check=True)
        checksum = hashlib.sha256()
        with (destination / name).open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                checksum.update(chunk)
        hashes[name] = checksum.hexdigest()
    (destination / "SHA256SUMS").write_text("".join(f"{value}  {name}\n" for name, value in hashes.items()))
    (destination / "COMPLETE").write_text("Local PC data backup complete\n")
    print(f"Local data backed up to {destination}")
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("start", "stop"))
    parser.add_argument(
        "--test-drivers", action="store_true", help="Enable the isolated artificial test population"
    )
    args = parser.parse_args()
    if sys.platform != "win32":
        raise RuntimeError("This launcher configures the Windows PC; use compose.pc.yaml directly on Linux")
    config = local_configuration()
    if args.test_drivers:
        enable_test_drivers(config)
    command = [
        "wsl",
        "-d",
        "Ubuntu",
        "--",
        # Windows process variables are not implicitly forwarded into WSL.
        *(["env", "BMT_TEST_DRIVERS_ENABLED=true"] if args.test_drivers else []),
        "docker",
        "compose",
        "--env-file",
        ".tools/bmt-pc.env",
        "-f",
        "backend/deploy/compose.pc.yaml",
    ]
    if args.action == "stop":
        subprocess.run([*command, "stop"], cwd=ROOT, check=True)
        print("PC backend stopped; accounts and tracks retained.")
        return
    # Never print resolved Compose config: it contains development credentials.
    # Python is bind-mounted, but the canonical Godot validator is baked into
    # the image. Build and verify it before replacing either running service.
    subprocess.run([*command, "build", "api"], cwd=ROOT, check=True)
    if args.test_drivers:
        # Also works when the local project is new or its database was stopped.
        subprocess.run([*command, "up", "-d", "--wait", "--wait-timeout", "90", "db"], cwd=ROOT, check=True)
        backup_local_data(command)
        subprocess.run([*command, "run", "--rm", "--no-deps", "-T", "migrate"], cwd=ROOT, check=True)
    subprocess.run([*command, "up", "-d", "--wait", "--wait-timeout", "90"], cwd=ROOT, check=True)
    probe = "import json; from bmt_backend.config import Settings; from bmt_backend.verifier import GodotVerifier; print(json.dumps(GodotVerifier(Settings.from_env()).manifest()))"
    manifests = []
    for service in ("api", "worker"):
        checked = subprocess.run(
            [*command, "exec", "-T", service, "python", "-c", probe],
            cwd=ROOT,
            check=True,
            capture_output=True,
            text=True,
        )
        manifests.append(json.loads(checked.stdout))
    if manifests[0] != manifests[1]:
        raise RuntimeError("API and worker verifier artifacts differ; client configuration was not changed")
    with urllib.request.urlopen(URL + "/v1/manifest", timeout=10) as response:
        live_manifest = json.load(response)
    if live_manifest != manifests[0]:
        raise RuntimeError("Live API and worker contracts differ; client configuration was not changed")
    configure_game(config)
    print(f"PC backend ready at {URL}. Reopen Sign in and choose Development.")
    print(
        "Google "
        + ("configured." if config.get("BMT_GOOGLE_WEB_CLIENT_ID") else "still needs an OAuth Web client ID.")
    )


if __name__ == "__main__":
    main()
