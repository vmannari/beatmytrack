"""Track identity review: disposable SQLite probes and read-only local API checks.

The domain probes use a deliberately fake verifier. Real canonical verification
is covered separately by the existing domain/verifier/end-to-end test commands.
Never reads credentials, submits player content, or modifies the running backend.
"""

import json
import logging
import os
import sys
import tempfile
import urllib.error
import urllib.request
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))

from fastapi.testclient import TestClient
from sqlalchemy import func, select

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.security import current_player
from bmt_backend.track_models import Track, TrackVersion
from bmt_backend.worker import process_one


class ReviewVerifier:
    def manifest(self):
        return {
            "engine_version": "review-engine", "verifier_version": "canonical-verifier-1",
            "rules_key": "standing-5-road-gates-v14", "physics_version": "arcade-planar-0.49",
            "compiler_version": "review-compiler", "track_schema": "creator-track-v5",
            "replay_schema": "bmt-replay-v1", "tick_rate": 120, "laps": 5,
            "max_frames": 216000,
            "vehicles": {"compact": {"handling_version": "review", "config_hash": "review"}},
        }

    def validate_track(self, document):
        return {**self.manifest(), "track_content_hash": "review-compiled-content", "route_length": 120.0}

    def verify_run(self, document, replay, vehicle_id, *, creator_test=False):
        laps = 1 if creator_test else 5
        return {"time_ticks": laps, "lap_ticks": [1] * laps, "manifest": self.validate_track(document)}


def domain_probes():
    with tempfile.TemporaryDirectory(prefix="bmt-track-review-") as folder:
        app = create_app(Settings(
            database_url="sqlite:///" + (Path(folder) / "review.sqlite").as_posix(),
            object_dir=str(Path(folder) / "objects"), write_limit_per_minute=1000,
        ), verifier=ReviewVerifier())
        upgrade(app.state.engine)
        try:
            with app.state.session_factory() as session:
                player = Player(display_name="Review creator")
                session.add(player)
                session.commit()
                session.expunge(player)
            app.dependency_overrides[current_player] = lambda: player
            with TestClient(app) as client:
                body = {"name": "Review loop", "document": {"id": "track_review", "name": "Review loop"}}

                def post(path, payload, key):
                    response = client.post(path, json=payload, headers={"Idempotency-Key": key})
                    assert response.is_success, response.text
                    return response.json()

                first = post("/v1/tracks", body, "review-upload-first")
                repeated = post("/v1/tracks", body, "review-upload-first")
                second = post("/v1/tracks", body, "review-upload-lost-map")
                changed_body = {"name": "Review loop changed", "document": {
                    **body["document"], "name": "Review loop changed"}}
                changed = post("/v1/tracks", changed_body, "review-upload-edit")
                for index, version in enumerate((first, second)):
                    ticket = post("/v1/run-tickets", {
                        "version_id": version["version_id"], "vehicle_id": "compact", "purpose": "creator_test",
                    }, f"review-ticket-{index}")
                    run = post("/v1/runs", {
                        "ticket_id": ticket["ticket_id"],
                        "replay": {"schema": "bmt-replay-v1", "frames": [[0, 255, 0]]},
                    }, f"review-run-{index}")
                    assert process_one(app)
                    status = client.get("/v1/runs/" + run["run_id"]).json()
                    assert status["status"] == "verified", status
                    post("/v1/track-versions/" + version["version_id"] + "/publish", {}, f"review-publish-{index}")
                public = client.get("/v1/tracks").json()["items"]
                with app.state.session_factory() as session:
                    track_count = session.scalar(select(func.count()).select_from(Track))
                    version_count = session.scalar(select(func.count()).select_from(TrackVersion))
                return {
                    "verifier": "fake domain verifier; not a driving proof",
                    "same_key_reuses_version": repeated["version_id"] == first["version_id"],
                    "different_key_same_document_creates_new_track": first["track_id"] != second["track_id"],
                    "different_key_same_document_has_same_blob_hash": first["content_hash"] == second["content_hash"],
                    "edited_same_document_id_creates_new_track": changed["track_id"] != first["track_id"],
                    "logical_tracks": track_count, "versions": version_count,
                    "published_identical_document_entries": len(public),
                    "published_identical_entries_have_distinct_track_ids": len({row["track_id"] for row in public}) == 2,
                }
        finally:
            app.state.engine.dispose()


def public_api_probes():
    output = {}
    for name, url in (
        ("readiness", "http://127.0.0.1:18181/readyz"),
        ("catalog", "http://127.0.0.1:18181/v1/tracks?limit=100"),
        ("manifest", "http://127.0.0.1:18181/v1/manifest"),
    ):
        try:
            with urllib.request.urlopen(url, timeout=10) as response:
                data = json.load(response)
            if name == "catalog":
                items = data.get("items", [])
                names = Counter((row.get("creator_id"), row.get("name")) for row in items)
                hashes = Counter((row.get("creator_id"), row.get("content_hash")) for row in items)
                output[name] = {
                    "items": len(items), "next_offset": data.get("next_offset"),
                    "duplicate_owner_name_groups": [{"name": key[1], "count": count}
                        for key, count in names.items() if count > 1],
                    "duplicate_owner_document_hash_groups": sum(count > 1 for count in hashes.values()),
                }
                output["local_catalog_overlap"] = local_catalog_probes(items)
            elif name == "manifest":
                output[name] = {key: data.get(key) for key in (
                    "engine_version", "physics_version", "rules_key", "compiler_version", "verifier_version")}
            else:
                output[name] = data
        except (OSError, urllib.error.URLError, ValueError) as error:
            output[name] = {"error": type(error).__name__}
    return output


def local_catalog_probes(public_items):
    """Read only actual authoring folders, excluding unrelated test directories."""
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return {"checked": False, "reason": "Windows application-data root unavailable"}
    root = Path(appdata) / "Circuit01Lab"
    if not root.is_dir():
        return {"checked": False, "reason": "Current custom user directory absent"}
    stores = [root / "tracks"]
    profiles = root / "players"
    if profiles.is_dir():
        stores.extend(path / "tracks" for path in profiles.iterdir() if path.is_dir())
    published_names = {row["name"] for row in public_items}
    local = []
    locked_names = []
    for store in stores:
        for path in store.glob("*.json"):
            try:
                if path.stat().st_size > 524288:
                    continue
                document = json.loads(path.read_text(encoding="utf-8-sig"))
                if document.get("schema") == "creator-track-v5":
                    local.append(document)
            except (OSError, ValueError):
                continue
        for path in (store / ".published").glob("*.json"):
            try:
                document = json.loads(path.read_text(encoding="utf-8-sig"))
                if document.get("schema") == "creator-track-v5":
                    locked_names.append(document.get("name"))
            except (OSError, ValueError):
                continue
    return {
        "checked": True, "player_files_modified": False,
        "scope": "guest and profile master folders; not an active-screen capture",
        "local_master_documents": len(local),
        "local_master_names_also_in_public_catalog": sorted({doc["name"] for doc in local} & published_names),
        "local_publication_lock_names_also_in_public_catalog": sorted(set(locked_names) & published_names),
        "matching_names_prove_overlap_only_not_content_equivalence": True,
    }


if __name__ == "__main__":
    logging.disable(logging.CRITICAL)
    result = {"disposable_domain": domain_probes(), "running_backend_read_only": public_api_probes()}
    destination = Path(__file__).with_name("workflow-probes.json")
    destination.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
