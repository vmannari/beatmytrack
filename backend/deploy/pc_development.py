"""Start the isolated PC backend and configure normal Godot/editor launches."""

import argparse
import configparser
import json
import os
import secrets
import subprocess
import sys
import urllib.request
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("start", "stop"))
    args = parser.parse_args()
    if sys.platform != "win32":
        raise RuntimeError("This launcher configures the Windows PC; use compose.pc.yaml directly on Linux")
    config = local_configuration()
    command = [
        "wsl",
        "-d",
        "Ubuntu",
        "--",
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
    subprocess.run([*command, "up", "-d", "--wait", "--wait-timeout", "90"], cwd=ROOT, check=True)
    probe = "import json; from bmt_backend.config import Settings; from bmt_backend.verifier import GodotVerifier; print(json.dumps(GodotVerifier(Settings.from_env()).manifest()))"
    manifests = []
    for service in ("api", "worker"):
        checked = subprocess.run([*command, "exec", "-T", service, "python", "-c", probe], cwd=ROOT,
                                 check=True, capture_output=True, text=True)
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
