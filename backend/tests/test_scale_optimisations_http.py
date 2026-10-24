"""Actual native outbox, packed transport, validator and reward transaction."""
import pytest
from sqlalchemy import select
from test_cloud_client import run_client
from test_cost_http import seed

from bmt_backend.track_models import Run, TrackVersion
from bmt_backend.tracks import DB, Auth


def prepare(app):
    seed(app)

    @app.get("/v1/scale-fixture")
    def fixture(session: DB, _player: Auth):
        return {"version_id": session.scalar(select(TrackVersion.id))}

    @app.get("/v1/scale-fixture/stored")
    def stored(ticket_id: str, session: DB, player: Auth):
        run = session.scalar(select(Run).where(Run.ticket_id == ticket_id, Run.player_id == player.id))
        return {"replay": app.state.blobs.get_json(run.replay_hash)}


@pytest.mark.godot
def test_native_packed_outbox_against_real_trajectory_worker(tmp_path):
    run_client(tmp_path, "res://tests/test_scale_optimisations_http.gd", prepare=prepare)
