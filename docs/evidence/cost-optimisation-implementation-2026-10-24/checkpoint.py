"""Capture task-start sources and later construct a task-only review checkpoint."""
import hashlib
import json
import subprocess
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
FILES = [
    "backend/bmt_backend/app.py", "backend/bmt_backend/config.py", "backend/bmt_backend/middleware.py",
    "backend/bmt_backend/observability.py", "backend/bmt_backend/storage.py", "backend/bmt_backend/gcs_storage.py",
    "backend/bmt_backend/s3_storage.py", "backend/bmt_backend/object_models.py", "backend/bmt_backend/maintenance.py",
    "backend/bmt_backend/rivalry.py", "backend/bmt_backend/challenges.py", "backend/bmt_backend/runs.py",
    "backend/bmt_backend/service_worker.py", "backend/bmt_backend/database_privileges.py",
    "backend/bmt_backend/economy.py", "backend/bmt_backend/economy_models.py", "backend/bmt_backend/track_models.py",
    "backend/bmt_backend/discovery_v3.py", "backend/bmt_backend/tracks.py", "backend/bmt_backend/privacy.py",
    "backend/deploy/gcp/staging.py", "backend/deploy/gcp/update.py", "backend/deploy/compose.cloud.yaml",
    "backend/deploy/.env.example", "backend/deploy/README.md", "backend/load_budgets.json",
    "game/backend/backend_client.gd", "game/backend/cloud_tracks.gd", "game/backend/weekly_rivalry_client.gd",
    "game/backend/challenges_client.gd", "game/backend/discovery_windows.gd", "game/backend/network_health.gd",
    "game/core/app.gd", "game/backend/menu_snapshot_writer.gd", "AGENTS.md", "DEVELOPMENT_STATUS.md",
]


def main():
    manifest = HERE / "baseline.json"
    if manifest.exists():
        print("Task-start baseline already retained")
        return
    baseline = {}
    for name in FILES:
        source = ROOT / name
        if not source.is_file():
            continue
        body = source.read_bytes()
        target = HERE / "before" / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(body)
        baseline[name] = hashlib.sha256(body).hexdigest()
    status = subprocess.run(["git", "status", "--porcelain=v1"], cwd=ROOT, capture_output=True,
                            text=True, check=True).stdout
    manifest.write_text(json.dumps({"sources": baseline, "git_status": status}, indent=2) + "\n", encoding="utf-8")
    print(f"Retained {len(baseline)} task-start sources")


if __name__ == "__main__":
    main()
