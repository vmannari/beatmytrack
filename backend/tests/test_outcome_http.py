"""Real authenticated native transport/consumers over a disposable HTTP API."""
import pytest
from test_cloud_client import run_client
from test_cost_http import seed

from bmt_backend.challenge_models import Challenge, ChallengeMember, ChallengeTicket
from bmt_backend.economy_models import CoinReward, CoinWallet
from bmt_backend.track_models import Run, RunTicket, now
from bmt_backend.tracks import DB, Auth


def prepare(app):
    seed(app)
    with app.state.session_factory() as session:
        challenge = session.query(Challenge).filter_by(code="A" * 16).one()
        run = session.get(Run, challenge.target_run_id)
        session.add(CoinWallet(player_id=run.player_id, balance=900, revision=3))
        session.add(CoinReward(run_id=run.id, player_id=run.player_id, amount=50,
            rows=[{"title": "Race completed", "amount": 50, "icon": "flag", "eligible": True, "status": "Credited"}]))
        challenge.attempt_limit = 3
        session.get(ChallengeMember, (challenge.id, run.player_id)).attempts_used = 2
        session.add(ChallengeTicket(ticket_id=run.ticket_id, challenge_id=challenge.id,
            outcome={"counted": True, "improved": True}))
        ticket = RunTicket(player_id=run.player_id, board_id=run.board_id, expires_at=now() + 600)
        session.add(ticket)
        session.flush()
        pending = Run(player_id=run.player_id, board_id=run.board_id, ticket_id=ticket.id,
                      replay_hash=run.replay_hash, status="queued", lease_until=now() + 600)
        session.add(pending)
        session.add(ChallengeTicket(ticket_id=ticket.id, challenge_id=challenge.id))
        session.flush()
        data = {"run_id": run.id, "ticket_id": run.ticket_id, "pending_run": pending.id, "pending_ticket": ticket.id}
        session.commit()

    @app.get("/v1/outcome-fixture")
    def fixture_state(_session: DB, _player: Auth):
        return data


@pytest.mark.godot
def test_native_completion_reads_against_http(tmp_path):
    run_client(tmp_path, "res://tests/test_outcome_reads_http.gd", prepare=prepare)
