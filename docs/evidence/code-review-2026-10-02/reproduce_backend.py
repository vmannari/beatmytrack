"""Isolated review probes. Temporary SQLite only; no production services or data."""

import json
import logging
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend"))

from fastapi.testclient import TestClient
from sqlalchemy import func, select

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player, RateBucket
from bmt_backend.migrate import upgrade
from bmt_backend.security import current_player
from bmt_backend.track_models import Run, TrackVersion
from bmt_backend.worker import process_one


class ReviewVerifier:
    def manifest(self):
        return {
            "engine_version": "review-engine", "verifier_version": "canonical-verifier-1",
            "rules_key": "standing-5-road-gates-v13", "physics_version": "arcade-planar-0.49",
            "compiler_version": "review-compiler", "track_schema": "creator-track-v5",
            "replay_schema": "bmt-replay-v1", "tick_rate": 120, "laps": 5,
            "max_frames": 216000,
            "vehicles": {"compact": {"handling_version": "review", "config_hash": "review"}},
        }

    def validate_track(self, document):
        return {**self.manifest(), "track_content_hash": "review-content", "route_length": 120.0}

    def verify_run(self, document, replay, vehicle_id):
        return {"time_ticks": 5, "lap_ticks": [1] * 5, "manifest": self.validate_track(document)}


def run():
    with tempfile.TemporaryDirectory(prefix="bmt-review-") as folder:
        settings = Settings(
            database_url="sqlite:///" + (Path(folder) / "review.sqlite").as_posix(),
            object_dir=str(Path(folder) / "objects"),
            google_client_ids=("review-client",), write_limit_per_minute=1000,
        )
        app = create_app(settings, verifier=ReviewVerifier())
        logging.disable(logging.CRITICAL)
        upgrade(app.state.engine)
        with app.state.session_factory() as db:
            player = Player(display_name="Review creator")
            db.add(player)
            db.commit()
            db.expunge(player)
        app.dependency_overrides[current_player] = lambda: player
        output = {}
        with TestClient(app) as client:
            uploaded = client.post("/v1/tracks", json={"name": "Review oval", "document": {}},
                                   headers={"Idempotency-Key": "review-upload-01"})
            assert uploaded.status_code == 201, uploaded.text
            version_id = uploaded.json()["version_id"]
            with app.state.session_factory() as db:
                version = db.get(TrackVersion, version_id)
                version.manifest = {**version.manifest, "physics_version": "arcade-planar-0.48"}
                db.commit()
            issued = client.post("/v1/run-tickets", json={"version_id": version_id, "vehicle_id": "compact"},
                                 headers={"Idempotency-Key": "review-ticket-01"})
            assert issued.status_code == 201, issued.text
            submitted = client.post("/v1/runs", json={"ticket_id": issued.json()["ticket_id"],
                                    "replay": {"schema": "bmt-replay-v1", "frames": [[0, 0, 0]] * 5}},
                                    headers={"Idempotency-Key": "review-submit-01"})
            assert submitted.status_code == 202, submitted.text
            assert process_one(app)
            with app.state.session_factory() as db:
                result = db.get(Run, submitted.json()["run_id"])
                output["physics_upgrade"] = {"ticket_status": issued.status_code,
                    "ticket_physics": issued.json()["manifest"]["physics_version"],
                    "worker_status": result.status, "failure_code": result.failure_code,
                    "attempts": result.attempts}
                assert result.status == "queued" and result.failure_code == "verifier_unavailable"
                version = db.get(TrackVersion, version_id)
                version.state, version.published_at = "published", 1
                db.commit()
            # Catalog hydration performs a filesystem blob read for every returned row.
            reads = []
            original = app.state.blobs.get_json
            def counted(digest):
                reads.append(digest)
                return original(digest)
            app.state.blobs.get_json = counted
            discovery = client.get("/v1/tracks")
            assert discovery.status_code == 200, discovery.text
            output["catalog_blob_reads"] = {"items": len(discovery.json()["items"]), "reads": len(reads)}
            auth_codes = [client.post("/v1/auth/google/challenge").status_code for _ in range(31)]
            output["shared_ip_auth_budget"] = {"successful": auth_codes.count(201),
                                                "rate_limited": auth_codes.count(429)}
            assert auth_codes == [201] * 30 + [429]
            with app.state.session_factory() as db:
                before = db.scalar(select(func.sum(RateBucket.count)))
            health_codes = [client.post("/healthz", json={"review": [0] * 100}).status_code for _ in range(40)]
            with app.state.session_factory() as db:
                after = db.scalar(select(func.sum(RateBucket.count)))
            output["health_post_budget_bypass"] = {"requests": len(health_codes),
                "method_not_allowed": health_codes.count(405), "budget_increment": after - before}
            assert health_codes == [405] * 40 and before == after
        app.state.engine.dispose()
        print(json.dumps(output, indent=2))


if __name__ == "__main__":
    run()
