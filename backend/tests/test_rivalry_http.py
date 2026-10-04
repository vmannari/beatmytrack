"""Native Race menu to disposable HTTP service to pinned canonical verifier."""
import copy
import json
from pathlib import Path

import pytest
from test_cloud_client import run_client

from bmt_backend.identity_models import Identity, Player
from bmt_backend.official_tracks import OFFICIAL_NAME, seed_documents


def seed(app):
    with app.state.session_factory() as session:
        owner = Player(display_name=OFFICIAL_NAME)
        session.add(owner)
        session.flush()
        session.add(Identity(player_id=owner.id, provider="development", subject="developer"))
        session.commit()
    root = Path(__file__).resolve().parents[2]
    fixture = json.loads((root / "backend/tests/fixtures/verified_oval.json").read_text())
    documents = []
    for index in range(5):
        doc = copy.deepcopy(fixture["document"])
        doc["id"], doc["name"] = f"weekly_fixture_{index}", f"Weekly fixture {index}"
        documents.append(doc)
    seed_documents(app.state.session_factory, app.state.blobs, app.state.verifier, documents)


@pytest.mark.godot
def test_weekly_rivalry_through_native_app(tmp_path):
    run_client(tmp_path, "res://tests/test_weekly_rivalry_http.gd", prepare=seed)


@pytest.mark.godot
def test_weekly_rivalry_immediate_continue(tmp_path):
    run_client(tmp_path, "res://tests/test_weekly_rivalry_http.gd", prepare=seed,
        extra_env={"BMT_RIVALRY_IMMEDIATE_CONTINUE":"true"})


@pytest.mark.godot
def test_test_rivalry_expired_session_at_finish(tmp_path):
    run_client(tmp_path, "res://tests/test_weekly_rivalry_http.gd", prepare=seed,
        settings_overrides={"test_drivers_enabled":True,"access_ttl_seconds":2},
        extra_env={"BMT_RIVALRY_EXPIRED_SESSION":"true"})


@pytest.mark.godot
def test_test_rivalry_restored_session_at_finish(tmp_path):
    run_client(tmp_path, "res://tests/test_weekly_rivalry_http.gd", prepare=seed,
        settings_overrides={"test_drivers_enabled":True},
        extra_env={"BMT_RIVALRY_SESSION_RESTORED":"true"})


@pytest.mark.godot
def test_test_rivalry_cross_process_session_at_finish(tmp_path):
    run_client(tmp_path, "res://tests/test_weekly_rivalry_http.gd", prepare=seed,
        settings_overrides={"test_drivers_enabled":True},
        extra_env={"BMT_RIVALRY_SESSION_RESTORED":"true","BMT_RIVALRY_CROSS_PROCESS":"true"})
