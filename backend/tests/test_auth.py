import json
import secrets
from dataclasses import replace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select, update

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Identity, LoginChallenge, Player, SessionFamily, SessionToken, now
from bmt_backend.migrate import upgrade


def headers(tokens):
    return {"Authorization": "Bearer " + tokens["access_token"]}


def test_google_account_uses_internal_id_and_reuses_identity(auth_app, auth_client, sign_in):
    first, second = sign_in("alice"), sign_in("alice")
    assert first["player"]["id"] == second["player"]["id"]
    assert first["player"]["id"] != "alice"
    assert auth_client.get("/v1/me", headers=headers(first)).json()["display_name"] == "alice"
    with auth_app.state.session_factory() as session:
        assert len(session.scalars(select(Player)).all()) == 1
        identity = session.scalar(select(Identity))
        assert identity.provider == "google" and identity.subject == "alice"
        stored = session.scalar(select(SessionToken))
        assert stored.access_hash != first["access_token"] and stored.refresh_hash != first["refresh_token"]


def test_nonce_required_single_use_and_expires(auth_app, auth_client):
    challenge = auth_client.post("/v1/auth/google/challenge").json()
    token = secrets.token_urlsafe(32)
    auth_app.state.identity_verifier.claims[token] = {"sub": "alice", "nonce": "wrong"}
    body = {"id_token": token, "challenge_id": challenge["challenge_id"]}
    assert auth_client.post("/v1/auth/google", json=body).status_code == 401
    auth_app.state.identity_verifier.claims[token]["nonce"] = challenge["nonce"]
    assert auth_client.post("/v1/auth/google", json=body).status_code == 200
    assert auth_client.post("/v1/auth/google", json=body).status_code == 401
    other = auth_client.post("/v1/auth/google/challenge").json()
    auth_app.state.identity_verifier.claims[token]["nonce"] = other["nonce"]
    body["challenge_id"] = other["challenge_id"]
    with auth_app.state.session_factory() as session:
        session.execute(update(LoginChallenge).values(expires_at=now() - 1))
        session.commit()
    assert auth_client.post("/v1/auth/google", json=body).status_code == 401


def test_refresh_rotation_reuse_revokes_family(auth_client, sign_in):
    original = sign_in()
    response = auth_client.post("/v1/auth/refresh", json={"refresh_token": original["refresh_token"]})
    assert response.status_code == 200
    replacement = response.json()
    assert auth_client.get("/v1/me", headers=headers(original)).status_code == 401
    assert auth_client.get("/v1/me", headers=headers(replacement)).status_code == 200
    assert (
        auth_client.post("/v1/auth/refresh", json={"refresh_token": original["refresh_token"]}).status_code
        == 401
    )
    assert auth_client.get("/v1/me", headers=headers(replacement)).status_code == 401


def test_logout_and_logout_all(auth_client, sign_in):
    one, two = sign_in(), sign_in()
    assert auth_client.post("/v1/auth/logout", headers=headers(one)).status_code == 204
    assert auth_client.get("/v1/me", headers=headers(one)).status_code == 401
    assert auth_client.get("/v1/me", headers=headers(two)).status_code == 200
    three = sign_in()
    assert auth_client.post("/v1/auth/logout-all", headers=headers(two)).status_code == 204
    assert auth_client.get("/v1/me", headers=headers(three)).status_code == 401


@pytest.mark.parametrize("field", ["access", "family", "disabled"])
def test_expiration_and_disabled_players(auth_app, auth_client, sign_in, field):
    tokens = sign_in()
    with auth_app.state.session_factory() as session:
        if field == "access":
            session.execute(update(SessionToken).values(access_expires_at=now() - 1))
        elif field == "family":
            session.execute(update(SessionFamily).values(expires_at=now() - 1))
        else:
            session.execute(update(Player).values(disabled=True))
        session.commit()
    assert auth_client.get("/v1/me", headers=headers(tokens)).status_code == 401


def test_validation_does_not_echo_tokens(auth_client):
    secret = "sensitive-token-must-not-be-echoed"
    response = auth_client.post("/v1/auth/google", json={"id_token": secret})
    assert response.status_code == 422 and secret not in response.text
    assert response.headers["cache-control"] == "no-store"
    assert "x-request-id" in response.headers


@pytest.mark.parametrize("body", ['{"a":1,"a":2}', '{"a":NaN}', '{"a":Infinity}', "[" * 40 + "0" + "]" * 40])
def test_malformed_json(auth_client, body):
    assert (
        auth_client.post(
            "/v1/auth/google", content=body, headers={"Content-Type": "application/json"}
        ).status_code
        == 400
    )


@pytest.mark.parametrize(
    "body",
    ['{"a":1e999}', '{"a":-1e999}', '{"refresh_token":"' + r"\ud800" * 32 + '"}', r'{"\ud800":"bad key"}'],
)
def test_json_rejects_overflow_and_unpaired_unicode(auth_client, body):
    response = auth_client.post(
        "/v1/auth/refresh", content=body, headers={"Content-Type": "application/json"}
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "INVALID_JSON"


def test_rate_budget_database_failure_is_structured_unavailable(auth_client, monkeypatch):
    from sqlalchemy.exc import OperationalError

    def unavailable(*_args, **_kwargs):
        raise OperationalError("SELECT private_database_details", {}, Exception("connection credentials"))

    monkeypatch.setattr("bmt_backend.middleware.check_budget", unavailable)
    response = auth_client.get("/v1/bootstrap")
    assert response.status_code == 503
    assert response.json()["detail"] == "DATABASE_UNAVAILABLE"
    assert "private_database_details" not in response.text and "credentials" not in response.text
    assert response.headers["x-request-id"]
    assert auth_client.get("/healthz").status_code == 200


@pytest.mark.parametrize(
    "field",
    [
        "verifier_timeout_seconds",
        "job_lease_seconds",
        "max_job_attempts",
        "access_ttl_seconds",
        "refresh_ttl_seconds",
        "max_body_bytes",
        "rate_limit_per_minute",
        "auth_limit_per_minute",
        "write_limit_per_minute",
    ],
)
def test_invalid_resource_budgets_rejected_at_startup(field):
    for value in (0, -1, True):
        with pytest.raises(ValueError):
            Settings(**{field: value})


def test_inconsistent_resource_bounds_rejected():
    with pytest.raises(ValueError):
        Settings(verifier_timeout_seconds=200, job_lease_seconds=180)
    with pytest.raises(ValueError):
        Settings(max_body_bytes=9 * 1024 * 1024)


def test_lease_covers_cold_manifest_replay_and_finalization():
    assert Settings().job_lease_seconds == 240
    for lease in (120, 180, 205):
        with pytest.raises(ValueError, match="twice"):
            Settings(verifier_timeout_seconds=90, job_lease_seconds=lease)
    assert Settings(verifier_timeout_seconds=90, job_lease_seconds=206).job_lease_seconds == 206


def test_non_ascii_development_header_does_not_raise(auth_app):
    settings = replace(
        auth_app.state.settings, environment="development", dev_auth_enabled=True, dev_auth_key="k" * 32
    )
    app = create_app(settings, engine=auth_app.state.engine)
    with TestClient(app) as client:
        response = client.post(
            "/v1/auth/development", json={"subject": "alice"}, headers={"X-Dev-Auth-Key": b"\xff" * 32}
        )
        assert response.status_code == 401


def test_large_or_compressed_requests(auth_client):
    assert auth_client.post("/v1/auth/google", content="x" * 32769).status_code == 413
    assert (
        auth_client.post("/v1/auth/google", content="{}", headers={"Content-Encoding": "gzip"}).status_code
        == 415
    )


def test_profile_cannot_change_authority(auth_client, sign_in):
    tokens = sign_in()
    assert (
        auth_client.patch("/v1/me", headers=headers(tokens), json={"display_name": "New Racer"}).status_code
        == 200
    )
    assert (
        auth_client.patch(
            "/v1/me", headers=headers(tokens), json={"display_name": "Name", "disabled": False}
        ).status_code
        == 422
    )
    assert (
        auth_client.patch("/v1/me", headers=headers(tokens), json={"display_name": "x\u202ey"}).status_code
        == 422
    )


def test_development_auth_is_explicit_separate_and_production_forbidden(auth_app, sign_in):
    with pytest.raises(ValueError):
        Settings(dev_auth_enabled=True, dev_auth_key="k" * 32)
    with pytest.raises(ValueError):
        Settings(environment="development", dev_auth_enabled=True, dev_auth_key="short")
    google = sign_in("alice")
    settings = replace(
        auth_app.state.settings, environment="development", dev_auth_enabled=True, dev_auth_key="k" * 32
    )
    app = create_app(settings, engine=auth_app.state.engine)
    with TestClient(app) as client:
        assert client.post("/v1/auth/development", json={"subject": "alice"}).status_code == 401
        response = client.post(
            "/v1/auth/development", json={"subject": "alice"}, headers={"X-Dev-Auth-Key": "k" * 32}
        )
        assert response.status_code == 200
        tokens = response.json()
        assert tokens["player"]["id"] != google["player"]["id"]
        assert client.get("/v1/me", headers=headers(tokens)).status_code == 200
        assert client.get("/v1/bootstrap").json()["development_auth"] is True
    with TestClient(auth_app) as client:
        assert (
            client.post(
                "/v1/auth/development", json={"subject": "alice"}, headers={"X-Dev-Auth-Key": "k" * 32}
            ).status_code
            == 404
        )


def test_rate_limit_shared_between_app_instances(auth_app):
    settings = replace(auth_app.state.settings, auth_limit_per_minute=2)
    one = create_app(settings, engine=auth_app.state.engine)
    two = create_app(settings, engine=auth_app.state.engine)
    with TestClient(one) as a, TestClient(two) as b:
        assert a.post("/v1/auth/google/challenge").status_code == 201
        assert b.post("/v1/auth/google/challenge").status_code == 201
        assert a.post("/v1/auth/google/challenge").status_code == 429


def test_migration_repeat_and_health(auth_app, auth_client):
    upgrade(auth_app.state.engine)
    assert auth_client.get("/healthz").status_code == 200
    assert auth_client.get("/readyz").status_code == 200
    assert json.loads(auth_client.get("/openapi.json").text)["info"]["version"] == "0.1.0"
