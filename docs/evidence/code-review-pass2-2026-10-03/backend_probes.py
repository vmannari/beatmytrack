"""Second review reproductions. Only a temporary SQLite DB and fixture identities."""
from __future__ import annotations

import json
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend" / "tests")]

from fastapi import HTTPException, Request
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from test_domains import FakeVerifier

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.operations import competition_health, heartbeat
from bmt_backend.security import current_player
from bmt_backend.track_models import TrackValidation
from bmt_backend.track_validation import process_one as validate_one


def main():
    result = {}
    with tempfile.TemporaryDirectory(prefix="review-pass2-", dir=ROOT / "build") as directory:
        root = Path(directory)
        app = create_app(Settings(database_url=f"sqlite:///{(root / 'db.sqlite').as_posix()}",
            object_dir=str(root / "objects"), rate_limit_per_minute=10000,
            write_limit_per_minute=10000), verifier=FakeVerifier())
        upgrade(app.state.engine)
        players = {}
        with app.state.session_factory() as session:
            for name in ("Fixture uploader", "Fixture editor"):
                player = Player(display_name=name)
                session.add(player)
                session.flush()
                players[name] = player.id
            session.commit()

        def fixture_identity(request: Request):
            with app.state.session_factory() as session:
                player = session.get(Player, request.headers.get("x-fixture-player", ""))
                if player is None:
                    raise HTTPException(401)
                session.expunge(player)
                return player

        app.dependency_overrides[current_player] = fixture_identity
        counter = 0

        def headers(player="Fixture uploader"):
            nonlocal counter
            counter += 1
            return {"x-fixture-player": players[player], "Idempotency-Key": f"review-fixture-{counter:08d}"}

        def body(identity, *, changed=False, large=False):
            doc = {"schema":"creator-track-v5", "id":identity, "name":"Fixture draft",
                   "shape":"changed" if changed else "oval", "points":[[0,0],[20,0],[20,20],[0,20]]}
            if large:
                doc["fixture_padding"] = "x" * 420000
            return {"name":doc["name"], "document":doc, "authoring_id":identity,
                    "defer_validation":True, "expected_head_revision_id":"new"}

        with TestClient(app) as client:
            accepted = [client.post("/v1/tracks", json=body(f"queued_{n}"), headers=headers()).status_code for n in range(8)]
            objects_before = len(list((root / "objects").glob("*/*.json")))
            rejected = [client.post("/v1/tracks", json=body(f"rejected_{n}", large=True), headers=headers()).status_code for n in range(3)]
            files_after = list((root / "objects").glob("*/*.json"))
            with app.state.session_factory() as session:
                active = session.scalar(select(func.count()).select_from(TrackValidation))
            result["rejected_upload_storage"] = {"accepted_statuses":accepted, "rejected_statuses":rejected,
                "object_count_before":objects_before, "object_count_after":len(files_after),
                "accepted_validation_rows":active, "object_bytes_after":sum(path.stat().st_size for path in files_after)}

            first = client.post("/v1/tracks", json=body("editor_revision"), headers=headers("Fixture editor"))
            assert first.status_code == 201, first.text
            old_expected = client.post("/v1/tracks", json=body("editor_revision", changed=True), headers=headers("Fixture editor"))
            correct = body("editor_revision", changed=True)
            correct["expected_head_revision_id"] = first.json()["version_id"]
            recovered = client.post("/v1/tracks", json=correct, headers=headers("Fixture editor"))
            result["stale_local_revision_parent"] = {"first_status":first.status_code,
                "stale_parent_status":old_expected.status_code, "stale_parent_detail":old_expected.json()["detail"],
                "current_parent_status":recovered.status_code}

            previous = app.state.verifier.manifest()
            app.state.verifier.manifest = lambda: {**previous, "rules_key":"standing-5-road-gates-v14",
                                                   "physics_version":"arcade-planar-0.49"}
            # This is the mixed Python/verifier state documented in the current deployment diagnosis.
            validated_body = body("mixed_build")
            validated_body["defer_validation"] = False
            version = client.post("/v1/tracks", json=validated_body, headers=headers("Fixture editor"))
            assert version.status_code == 201, version.text
            build = {key:app.state.verifier.manifest()[key] for key in ("engine_version","verifier_version","physics_version","rules_key")}
            heartbeat(app, "fixture-worker", phase="claiming", build=build)
            health = competition_health(app)
            issued = client.post("/v1/run-tickets", json={"version_id":version.json()["version_id"],
                "vehicle_id":"compact"}, headers=headers("Fixture editor"))
            result["mixed_build_competition_health"] = {"competition_status":health["status"],
                "expected_rules":health["expected_build"]["rules_key"], "ticket_status":issued.status_code,
                "ticket_detail":issued.json().get("detail")}

            page = client.get(f"/v1/track-versions/{version.json()['version_id']}/leaderboard?offset=10020")
            result["legacy_leaderboard_page_limit"] = {"requested_offset":10020,
                "response_status":page.status_code, "detail":page.json().get("detail")}

            first_version = first.json()["version_id"]
            with app.state.session_factory() as session:
                for row in session.scalars(select(TrackValidation)):
                    row.lease_until = 2_000_000_000
                row = session.get(TrackValidation, first_version)
                row.status, row.attempts, row.lease_until = "validating", app.state.settings.max_job_attempts, 0
                session.commit()
            processed = validate_one(app)
            with app.state.session_factory() as session:
                row = session.get(TrackValidation, first_version)
                result["expired_validation_retry_budget"] = {"configured_max_attempts":app.state.settings.max_job_attempts,
                    "processed":processed, "attempts_after_reclaim":row.attempts, "status_after_reclaim":row.status}
        app.state.engine.dispose()

    destination = Path(__file__).with_name("backend-probes.json")
    destination.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
