"""Owned loopback purchase lab, isolated from all existing cloud/NAS player data."""
import argparse
import secrets
from pathlib import Path

import uvicorn

from .app import create_app
from .config import Settings
from .migrate import upgrade


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--port", type=int, default=18182)
    parser.add_argument("--godot-bin", required=True)
    parser.add_argument("--worker", action="store_true")
    parser.add_argument("--seed-catalog", action="store_true")
    args = parser.parse_args()
    folder = args.data_dir.resolve()
    folder.mkdir(parents=True, exist_ok=True)
    key_path = folder / "development.key"
    if not key_path.exists():
        key_path.write_text(secrets.token_urlsafe(48), encoding="utf-8")
    key = key_path.read_text(encoding="utf-8").strip()
    admin_key_path = folder / "admin-owner.key"
    if not admin_key_path.exists():
        admin_key_path.write_text(secrets.token_urlsafe(48), encoding="utf-8")
    settings = Settings(environment="development", dev_auth_enabled=True,
        dev_auth_key=key, purchase_simulation_enabled=True,
        admin_owner_key=admin_key_path.read_text(encoding="utf-8").strip(),
        database_url="sqlite:///" + (folder / "lab.sqlite").as_posix(),
        public_base_url=f"http://127.0.0.1:{args.port}", object_dir=str(folder / "objects"),
        godot_bin=args.godot_bin, allow_sync_track_validation=True,
        rate_limit_per_minute=10000, write_limit_per_minute=5000, auth_limit_per_minute=1000)
    app = create_app(settings)
    if args.worker:
        from .worker import process_one
        from .worker_lifecycle import run_worker
        run_worker(app, process_one)
        return
    upgrade(app.state.engine)
    if args.seed_catalog:
        from .purchase_lab_catalog import seed_lab_catalog
        try:
            print(seed_lab_catalog(app), flush=True)
        finally:
            app.state.verifier.close()
            app.state.engine.dispose()
        return
    print("Purchase lab on loopback; simulation only. Private key stays in the lab directory.")
    uvicorn.run(app, host="127.0.0.1", port=args.port, log_level="warning")


if __name__ == "__main__":
    main()
