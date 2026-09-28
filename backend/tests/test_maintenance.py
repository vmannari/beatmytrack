from sqlalchemy import select, update

from bmt_backend.identity_models import LoginChallenge, Player, SessionFamily, SessionToken, now
from bmt_backend.maintenance import cleanup


def test_expiration_removes_tokens_but_preserves_account(auth_app, sign_in):
    sign_in()
    with auth_app.state.session_factory() as session:
        session.execute(update(LoginChallenge).values(expires_at=now() - 1))
        session.execute(update(SessionFamily).values(expires_at=now() - 1))
        session.commit()
    result = cleanup(auth_app.state.session_factory)
    assert result["session_families"] == 1 and result["login_challenges"] == 1
    with auth_app.state.session_factory() as session:
        assert session.scalar(select(Player)) is not None
        assert session.scalar(select(SessionToken)) is None
