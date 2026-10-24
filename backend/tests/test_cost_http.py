"""Native decoder/cache against an isolated authenticated HTTP API."""
import json
from pathlib import Path

import pytest
from test_cloud_client import run_client

from bmt_backend.challenge_models import Challenge, ChallengeMember
from bmt_backend.identity_models import Identity, Player
from bmt_backend.official_tracks import OFFICIAL_NAME
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import Board, Run, RunTicket, Track, TrackVersion, digest, now
from bmt_backend.tracks import DB, Auth

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "docs/evidence/cost-optimisation-implementation-2026-10-24/ghost-wire-fixture.json"


def prepare(app):
    try:
        seed(app)
    except BaseException:
        app.state.verifier.close()
        raise


def seed(app):
    # Disposable prepared rows exercise presentation IO, not race acceptance.
    recording = json.loads(FIXTURE.read_text())["original"]
    document = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())["document"]
    body_hash, ghost_hash = app.state.blobs.put_json(document), app.state.blobs.put_json(recording)
    with app.state.session_factory() as session:
        owner = Player(display_name=OFFICIAL_NAME)
        session.add(owner)
        session.flush()
        session.add(Identity(player_id=owner.id, provider="development", subject="developer"))
        track = Track(owner_id=owner.id, official=True)
        session.add(track)
        session.flush()
        version = TrackVersion(track_id=track.id, number=1, name="Cost fixture", state="published", content_hash=body_hash,
            manifest=app.state.verifier.validate_track(document), discovery={"theme": "pine", "points": document.get("points", [])}, published_at=now())
        session.add(version)
        session.flush()
        manifest = board_manifest(version, "compact")
        board = Board(id=digest(manifest), version_id=version.id, vehicle_id="compact", manifest=manifest)
        session.add(board)
        session.flush()
        ticket = RunTicket(player_id=owner.id, board_id=board.id, expires_at=now()+600)
        session.add(ticket)
        session.flush()
        run = Run(ticket_id=ticket.id, player_id=owner.id, board_id=board.id, replay_hash=body_hash, ghost_hash=ghost_hash,
                  status="verified", time_ticks=int(recording["ticks"]), finished_at=now(), lap_ticks=[1, 1, 1, 1, int(recording["ticks"])-4])
        session.add(run)
        session.flush()
        challenge = Challenge(code="A"*16, creator_id=owner.id, board_id=board.id, mode="beat", target_run_id=run.id,
            target_ticks=run.time_ticks, ends_at=now()+600)
        session.add(challenge)
        session.flush()
        session.add(ChallengeMember(challenge_id=challenge.id, player_id=owner.id, run_id=run.id, time_ticks=run.time_ticks))
        session.commit()
    @app.post("/v1/cost-fixture/disable")
    def disable(session: DB, player: Auth):
        # Exercise withdrawal without attempting to disable the authenticated
        # actor inside a write guarded by the account-deletion commit fence.
        track = session.get(Track, version.track_id)
        assert track.owner_id == player.id
        track.hidden = True
        session.commit()
        return {"disabled": True}


@pytest.mark.godot
def test_native_cost_downloads_against_http(tmp_path):
    run_client(tmp_path, "res://tests/test_cost_downloads_http.gd", prepare=prepare,
        settings_overrides={"object_packing_enabled": True},
        extra_env={"BMT_GHOST_WIRE_FIXTURE": str(FIXTURE), "BMT_NATIVE_COST_CACHE": str(tmp_path / "recording-cache")})
