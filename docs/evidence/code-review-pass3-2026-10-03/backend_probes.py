"""Third-pass probes against isolated fixture storage and database only."""
from __future__ import annotations

import json
import logging
import os
import sys
import tempfile
from pathlib import Path
from time import perf_counter

ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / "backend"), str(ROOT / "backend" / "tests")]

from fastapi import Request
from fastapi.testclient import TestClient
from sqlalchemy import event, text
from test_domains import FakeVerifier

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.maintenance import retain
from bmt_backend.middleware import parse_body
from bmt_backend.migrate import upgrade
from bmt_backend.security import current_player
from bmt_backend.storage import canonical_json
from bmt_backend.track_models import Run, Track, TrackVersion, now
from bmt_backend.verifier import MAX_REQUEST_BYTES, VerificationError, _json_bytes, validate_replay
from bmt_backend.worker import process_one


class EnvelopeVerifier(FakeVerifier):
    """Exercise the real serializer before a canonical subprocess would start."""
    def verify_run(self, document, replay, vehicle_id, *, creator_test=False):
        _json_bytes({"operation": "run", "document": document,
                     "replay": replay, "vehicle_id": vehicle_id}, MAX_REQUEST_BYTES)
        return super().verify_run(document, replay, vehicle_id, creator_test=creator_test)


def main():
    output = {}
    build = (ROOT / "build").resolve()
    with tempfile.TemporaryDirectory(prefix="review-pass3-", dir=build) as directory:
        root = Path(directory).resolve()
        assert root.is_relative_to(build) and root.name.startswith("review-pass3-")
        app = create_app(Settings(database_url=f"sqlite:///{(root / 'db.sqlite').as_posix()}",
            object_dir=str(root / "objects"), rate_limit_per_minute=10000,
            write_limit_per_minute=10000), verifier=EnvelopeVerifier())
        logging.getLogger("bmt.requests").disabled = True
        upgrade(app.state.engine)
        with app.state.session_factory() as session:
            player = Player(display_name="Third review fixture")
            session.add(player)
            session.flush()
            player_id = player.id
            parent = Track(owner_id=player_id, authoring_id="retention_fixture")
            session.add(parent)
            session.flush()
            parent_id = parent.id
            session.commit()

        def fixture_identity(_request: Request):
            with app.state.session_factory() as session:
                player = session.get(Player, player_id)
                session.expunge(player)
                return player

        app.dependency_overrides[current_player] = fixture_identity
        results = []
        for channels in (3, 4):
            replay = {"schema": "bmt-replay-v1", "frames": [[0] * channels for _ in range(216000)]}
            wire = canonical_json(replay)
            parse_body(wire)
            validate_replay(replay)
            error = ""
            try:
                _json_bytes({"operation": "run", "document": {"schema":"creator-track-v5"},
                    "replay": replay, "vehicle_id":"compact"}, MAX_REQUEST_BYTES)
            except VerificationError as failure:
                error = str(failure)
            results.append({"channels":channels, "frames":len(replay["frames"]),
                "wire_bytes":len(wire), "http_boundary_accepts":True,
                "replay_schema_accepts":True, "verifier_envelope_error":error})
        output["advertised_replay_limit"] = results
        with TestClient(app) as client:
            uploaded = client.post("/v1/tracks", json={"name":"Replay envelope fixture",
                "document":{"schema":"creator-track-v5", "id":"replay_fixture", "shape":"oval"}},
                headers={"Idempotency-Key":"review3-upload-fixture"})
            assert uploaded.status_code == 201, uploaded.text
            ticket = client.post("/v1/run-tickets", json={"version_id":uploaded.json()["version_id"],
                "vehicle_id":"compact"}, headers={"Idempotency-Key":"review3-ticket-fixture"})
            assert ticket.status_code == 201, ticket.text
            submitted = client.post("/v1/runs", json={"ticket_id":ticket.json()["ticket_id"],
                "replay":replay}, headers={"Idempotency-Key":"review3-submit-fixture"})
            assert submitted.status_code == 202, submitted.text
            process_one(app)
            with app.state.session_factory() as session:
                run = session.get(Run, submitted.json()["run_id"])
                output["accepted_replay_worker_outcome"] = {"submit_status":submitted.status_code,
                    "worker_status":run.status, "failure_code":run.failure_code,
                    "canonical_subprocess_started":False}

        query_count = 0

        def count_query(_connection, _cursor, statement, _parameters, _context, _many):
            nonlocal query_count
            if statement.lstrip().upper().startswith("SELECT"):
                query_count += 1

        event.listen(app.state.engine, "before_cursor_execute", count_query)
        scans = []
        population = 0
        for target in (250, 1500):
            with app.state.session_factory() as session:
                for number in range(population, target):
                    digest = app.state.blobs.put_json({"retention_fixture":number})
                    os.utime(app.state.blobs._path(digest), (now() - 172800, now() - 172800))
                    session.add(TrackVersion(track_id=parent_id, number=number+1,
                        name=f"Fixture {number}", content_hash=digest, manifest={}, state="draft"))
                session.commit()
            population = target
            query_count = 0
            started = perf_counter()
            result = retain(app.state.session_factory, app.state.blobs)
            scans.append({"referenced_old_objects":target, "select_queries":query_count,
                "elapsed_ms":round((perf_counter()-started)*1000, 3),
                "orphan_candidates":result["orphaned_objects"], "dry_run":not result["applied"]})
        output["retention_scan_work"] = scans
        event.remove(app.state.engine, "before_cursor_execute", count_query)
        with app.state.engine.connect() as connection:
            output["retention_reference_lookup_plan"] = [row[3] for row in connection.execute(
                text("EXPLAIN QUERY PLAN SELECT id FROM track_versions WHERE content_hash=:hash LIMIT 1"),
                {"hash":digest})]
        app.state.engine.dispose()
    destination = Path(__file__).with_name("backend-probes.json")
    destination.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(output, indent=2))


if __name__ == "__main__":
    main()
