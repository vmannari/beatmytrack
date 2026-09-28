"""Actual PostgreSQL lock/savepoint behavior for identity and session rotation."""

from __future__ import annotations

import os
import secrets
import threading
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from pathlib import Path

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event, inspect, select, text

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Identity, Player, SessionFamily, SessionToken
from bmt_backend.migrate import upgrade

pytestmark = pytest.mark.postgres


def test_browser_poll_is_single_use_under_concurrency(postgres_auth):
    app, client = postgres_auth
    app.state.settings = replace(
        app.state.settings, google_web_client_id="test-client", public_base_url="https://game.example"
    )
    started = client.post("/v1/auth/google/browser/start", json={"display_name": "Chosen name"}).json()
    browser = started["browser_url"].split("#")[1]
    config = client.post("/v1/auth/google/browser/prepare", json={"token": browser}).json()
    token = secrets.token_urlsafe(32)
    app.state.identity_verifier.claims[token] = {
        "sub": "browser-player",
        "aud": "test-client",
        "nonce": config["nonce"],
    }
    assert (
        client.post(
            "/v1/auth/google/browser/complete", json={"token": browser, "id_token": token}
        ).status_code
        == 200
    )
    barrier = threading.Barrier(2)

    def poll():
        with TestClient(app) as other:
            barrier.wait(timeout=10)
            return other.post(
                "/v1/auth/google/browser/poll", json={"token": started["poll_token"]}
            ).status_code

    with ThreadPoolExecutor(max_workers=2) as executor:
        futures = [executor.submit(poll) for _ in range(2)]
        assert sorted(f.result(timeout=20) for f in futures) == [200, 401]
    with app.state.session_factory() as session:
        assert len(session.scalars(select(SessionFamily)).all()) == 1
        assert session.scalar(select(Player)).display_name == "Chosen name"


class IsolatedGoogle:
    def __init__(self):
        self.claims = {}

    def verify(self, token):
        if token not in self.claims:
            raise HTTPException(401, "INVALID_GOOGLE_TOKEN")
        return self.claims[token]


@pytest.fixture
def postgres_auth(tmp_path):
    database_url = os.environ.get("BMT_TEST_DATABASE_URL")
    local_config = Path(__file__).resolve().parents[2] / ".tools" / "backend-postgres.env"
    if not database_url and local_config.is_file():
        for line in local_config.read_text().splitlines():
            if line.startswith("BMT_TEST_DATABASE_URL="):
                database_url = line.split("=", 1)[1].strip()
    if not database_url:
        pytest.skip("Set BMT_TEST_DATABASE_URL to an isolated disposable PostgreSQL database")
    schema = "test_auth_" + uuid.uuid4().hex
    admin = create_engine(database_url, connect_args={"connect_timeout": 5})
    with admin.begin() as connection:
        connection.exec_driver_sql(f"CREATE SCHEMA {schema}")
    engine = create_engine(
        database_url,
        connect_args={
            "connect_timeout": 5,
            "options": f"-c search_path={schema} -c statement_timeout=15000",
        },
    )
    try:
        settings = Settings(
            database_url=database_url,
            object_dir=str(tmp_path / "objects"),
            google_client_ids=("test-client",),
            auth_limit_per_minute=1000,
        )
        app = create_app(settings, engine=engine, identity_verifier=IsolatedGoogle())
        upgrade(engine)
        with TestClient(app) as client:
            yield app, client
    finally:
        engine.dispose()
        # Only the randomly named schema created above is removed.
        with admin.begin() as connection:
            connection.exec_driver_sql(f"DROP SCHEMA {schema} CASCADE")
        admin.dispose()


def google_request(app, client, subject):
    challenge = client.post("/v1/auth/google/challenge")
    assert challenge.status_code == 201, challenge.text
    data = challenge.json()
    token = secrets.token_urlsafe(32)
    app.state.identity_verifier.claims[token] = {"sub": subject, "nonce": data["nonce"]}
    return {"id_token": token, "challenge_id": data["challenge_id"], "display_name": "Concurrent racer"}


def test_postgres_concurrent_refresh_reuse_revokes_entire_family(postgres_auth):
    app, client = postgres_auth
    response = client.post("/v1/auth/google", json=google_request(app, client, "refresh-racer"))
    assert response.status_code == 200, response.text
    original = response.json()
    start = threading.Barrier(2)

    def refresh(_index):
        start.wait(timeout=10)
        return client.post("/v1/auth/refresh", json={"refresh_token": original["refresh_token"]})

    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(refresh, range(2)))
    assert sorted(item.status_code for item in responses) == [200, 401]
    replacement = next(item.json() for item in responses if item.status_code == 200)
    for token in (original, replacement):
        assert (
            client.get("/v1/me", headers={"Authorization": "Bearer " + token["access_token"]}).status_code
            == 401
        )
    with app.state.session_factory() as session:
        assert session.scalar(select(SessionFamily)).revoked is True
        assert len(session.scalars(select(SessionToken)).all()) == 2


def test_postgres_simultaneous_google_identity_creation_has_one_player(postgres_auth):
    app, client = postgres_auth
    bodies = [google_request(app, client, "same-google-subject") for _ in range(2)]
    inserting_identity = threading.Barrier(2)

    def synchronize_identity_insert(_connection, _cursor, statement, _parameters, _context, _many):
        # Both requests must first observe no existing identity, exercising the
        # unique-constraint/savepoint race instead of sequential sign-in reuse.
        if statement.startswith("INSERT INTO identities "):
            inserting_identity.wait(timeout=10)

    event.listen(app.state.engine, "before_cursor_execute", synchronize_identity_insert)
    try:
        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(pool.map(lambda body: client.post("/v1/auth/google", json=body), bodies))
    finally:
        event.remove(app.state.engine, "before_cursor_execute", synchronize_identity_insert)
    assert [response.status_code for response in responses] == [200, 200], [r.text for r in responses]
    assert len({response.json()["player"]["id"] for response in responses}) == 1
    with app.state.session_factory() as session:
        assert len(session.scalars(select(Player)).all()) == 1
        assert len(session.scalars(select(Identity)).all()) == 1
        assert len(session.scalars(select(SessionFamily)).all()) == 2


def test_postgres_migration_second_pass_preserves_schema_and_data(postgres_auth):
    app, client = postgres_auth
    signed_in = client.post("/v1/auth/google", json=google_request(app, client, "migration-racer"))
    assert signed_in.status_code == 200, signed_in.text
    before = inspect(app.state.engine).get_table_names()
    upgrade(app.state.engine)
    assert inspect(app.state.engine).get_table_names() == before
    with app.state.engine.connect() as connection:
        assert connection.scalar(text("SELECT version_num FROM alembic_version")) == "0002_browser_login"
    assert (
        client.get(
            "/v1/me", headers={"Authorization": "Bearer " + signed_in.json()["access_token"]}
        ).status_code
        == 200
    )
    assert client.get("/readyz").status_code == 200
