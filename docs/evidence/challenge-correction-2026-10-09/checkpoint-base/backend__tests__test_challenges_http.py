"""A real native menu, two isolated identities and canonical ghost verification."""
import os
from pathlib import Path
from types import SimpleNamespace

import pytest
from sqlalchemy import select
from test_cloud_client import run_client
from test_rivalry_http import seed

from bmt_backend.challenge_models import Challenge
from bmt_backend.challenges import preview


class FixtureIdentity:
    def verify(self, token):
        # Only injected into this disposable test app; production authentication is unchanged.
        assert token.startswith("challenge-fixture:")
        return {"sub": "challenge-http-recipient", "nonce": token.split(":", 1)[1]}


def prepare(app):
    seed(app)
    app.state.identity_verifier = FixtureIdentity()


@pytest.mark.godot
def test_complete_challenge_through_native_app(tmp_path):
    prepared = []
    def prepare_capture(app):
        prepare(app)
        prepared.append(app)
    run_client(tmp_path, "res://tests/test_challenges_http.gd", prepare=prepare_capture,
               settings_overrides={"google_client_ids": ("challenge-fixture-client",)})
    directory = os.environ.get("BMT_CAPTURE_CLOUD")
    if directory:
        app = prepared[0]
        with app.state.session_factory() as session:
            challenge = session.scalar(select(Challenge).where(Challenge.mode == "beat").order_by(Challenge.created_at))
            page = preview(challenge.code, SimpleNamespace(app=app), session)
            Path(directory, "preview.html").write_bytes(page.body)
        app.state.engine.dispose()


@pytest.mark.godot
def test_race_to_set_challenge_returns_to_creation(tmp_path):
    run_client(tmp_path, "res://tests/test_challenges_http.gd", prepare=prepare,
               settings_overrides={"google_client_ids": ("challenge-fixture-client",)},
               extra_env={"BMT_CHALLENGE_SEED_FLOW": "true"})
