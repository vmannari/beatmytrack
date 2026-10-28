"""Three real native identities share a group created from a completed race."""
import pytest
from test_challenges_http import prepare
from test_cloud_client import run_client


class GroupFixtureIdentity:
    def verify(self, token):
        # Injected only into the disposable fixture app.
        label, nonce = token.split(":", 1)
        assert label in {"group-first", "group-second"}
        return {"sub": label, "nonce": nonce}


@pytest.mark.godot
def test_results_group_three_players_best_only_and_exhausted_tries(tmp_path):
    def prepare_group(app):
        prepare(app)
        app.state.identity_verifier = GroupFixtureIdentity()

    run_client(
        tmp_path, "res://tests/test_challenge_group_http.gd", prepare=prepare_group,
        settings_overrides={"google_client_ids": ("challenge-fixture-client",)},
    )
