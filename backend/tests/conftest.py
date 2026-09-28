import pytest
from fastapi.testclient import TestClient

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.migrate import upgrade


class TestIdentity:
    def __init__(self):
        self.claims = {}

    def verify(self, token):
        from fastapi import HTTPException

        if token not in self.claims:
            raise HTTPException(401, "INVALID_GOOGLE_TOKEN")
        return self.claims[token]


@pytest.fixture
def auth_app(tmp_path):
    settings = Settings(
        database_url=f"sqlite:///{(tmp_path / 'db.sqlite').as_posix()}",
        object_dir=str(tmp_path / "objects"),
        google_client_ids=("test-client",),
        auth_limit_per_minute=1000,
        write_limit_per_minute=1000,
    )
    app = create_app(settings, identity_verifier=TestIdentity())
    upgrade(app.state.engine)
    yield app
    app.state.engine.dispose()


@pytest.fixture
def auth_client(auth_app):
    with TestClient(auth_app) as client:
        yield client


@pytest.fixture
def sign_in(auth_app, auth_client):
    def perform(subject="alice", **extra):
        import secrets

        challenge = auth_client.post("/v1/auth/google/challenge").json()
        token = secrets.token_urlsafe(32)
        auth_app.state.identity_verifier.claims[token] = {"sub": subject, "nonce": challenge["nonce"]}
        body = {
            "id_token": token,
            "challenge_id": challenge["challenge_id"],
            "display_name": subject,
            **extra,
        }
        response = auth_client.post("/v1/auth/google", json=body)
        assert response.status_code == 200, response.text
        return response.json()

    return perform
