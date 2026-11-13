"""Real Godot upload/recovery/reward flow over an owned disposable HTTP API."""
import json
from pathlib import Path

import pytest
from test_cloud_client import run_client

from bmt_backend.track_models import Board, PersonalBest, Run, RunTicket, Track, TrackVersion, digest, now
from bmt_backend.tracks import DB, Auth


@pytest.mark.godot
def test_native_non_improving_upload_against_http(tmp_path):
    calls = []

    def prepare(app):
        fixture = json.loads((Path(__file__).parent / "fixtures/verified_oval.json").read_text())
        manifest = app.state.verifier.validate_track(fixture["document"])
        content = app.state.blobs.put_json(fixture["document"])
        replay_hash = app.state.blobs.put_json(fixture["replay"])
        original = app.state.verifier.verify_run

        def observed(*args, **kwargs):
            calls.append(True)
            return original(*args, **kwargs)

        app.state.verifier.verify_run = observed

        @app.get("/v1/skip-fixture/count")
        def verification_count():
            return {"calls":len(calls)}

        @app.post("/v1/skip-fixture")
        def seed(session: DB, player: Auth):
            from bmt_backend.runs import board_manifest
            track = Track(owner_id=player.id, official=True)
            session.add(track)
            session.flush()
            version = TrackVersion(track_id=track.id, number=1, name="Skip verification fixture",
                state="published", published_at=now(), content_hash=content, manifest=manifest,
                discovery={"theme":"grass", "points":[[0,0],[10,0],[10,10]]})
            session.add(version)
            session.flush()
            pinned = board_manifest(version,"compact")
            board = Board(id=digest({"version_id":version.id, **pinned}), version_id=version.id,
                          vehicle_id="compact", manifest=pinned)
            session.add(board)
            session.flush()
            ticket = RunTicket(player_id=player.id,board_id=board.id,expires_at=now()+7200)
            session.add(ticket)
            session.flush()
            run = Run(ticket_id=ticket.id,player_id=player.id,board_id=board.id,replay_hash=replay_hash,
                      status="verified",time_ticks=12757,lap_ticks=[2634,2532,2531,2530,2530],finished_at=now())
            session.add(run)
            session.flush()
            session.add(PersonalBest(board_id=board.id,player_id=player.id,run_id=run.id,time_ticks=12757))
            session.commit()
            return {"version_id":version.id, "board_id":board.id, "source_run_id":run.id,
                    "lap_ticks":[2634,2532,2531,2530,2530]}

    run_client(tmp_path,"res://tests/test_non_improving_http.gd",prepare=prepare,
               extra_env={"BMT_SKIP_NATIVE_ROOT":str(tmp_path/"native")})
    assert len(calls) == 1, "Only the explicitly requested competitive reuse should invoke verification"
