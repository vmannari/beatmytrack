import secrets
from dataclasses import replace

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import select, update

from bmt_backend.app import create_app
from bmt_backend.identity_models import BrowserLogin, now
from bmt_backend.maintenance import cleanup


@pytest.fixture
def browser(auth_app):
    settings = replace(
        auth_app.state.settings, google_web_client_id="test-client", public_base_url="https://game.example"
    )
    app = create_app(
        settings, engine=auth_app.state.engine, identity_verifier=auth_app.state.identity_verifier
    )
    with TestClient(app) as client:
        yield client, app


def start(client, name="Chosen racer"):
    response = client.post("/v1/auth/google/browser/start", json={"display_name": name})
    assert response.status_code == 201, response.text
    data = response.json()
    return data["browser_url"].split("#")[1], data["poll_token"]


def complete(client, app, browser_token, subject="google-subject", **claims):
    config = client.post("/v1/auth/google/browser/prepare", json={"token": browser_token}).json()
    token = secrets.token_urlsafe(32)
    app.state.identity_verifier.claims[token] = {
        "sub": subject,
        "aud": "test-client",
        "nonce": config["nonce"],
        **claims,
    }
    return client.post("/v1/auth/google/browser/complete", json={"token": browser_token, "id_token": token})


def test_chosen_username_and_existing_google_identity(browser):
    client, app = browser
    browser_token, poll_token = start(client)
    assert client.post("/v1/auth/google/browser/poll", json={"token": poll_token}).json() == {
        "status": "pending"
    }
    assert complete(client, app, browser_token).json() == {"status": "complete"}
    first = client.post("/v1/auth/google/browser/poll", json={"token": poll_token})
    assert first.status_code == 200
    assert first.json()["player"]["display_name"] == "Chosen racer"
    assert client.post("/v1/auth/google/browser/poll", json={"token": poll_token}).status_code == 401
    assert client.post("/v1/auth/google/browser/prepare", json={"token": browser_token}).status_code == 401
    b2, p2 = start(client, "Different name on next login")
    assert complete(client, app, b2).status_code == 200
    second = client.post("/v1/auth/google/browser/poll", json={"token": p2}).json()
    assert second["player"] == first.json()["player"]


@pytest.mark.parametrize("wrong", [{"nonce": "wrong"}, {"nonce": "väärä"}, {"aud": "other-client"}])
def test_browser_rejects_wrong_nonce_or_audience(browser, wrong):
    client, app = browser
    browser_token, poll_token = start(client)
    assert complete(client, app, browser_token, **wrong).status_code == 401
    assert client.post("/v1/auth/google/browser/poll", json={"token": poll_token}).json() == {
        "status": "pending"
    }


def test_handoff_secrets_separate_hashed_and_cancelled(browser):
    client, app = browser
    b, p = start(client)
    with app.state.session_factory() as session:
        row = session.scalar(select(BrowserLogin))
        assert row.browser_hash != b and row.poll_hash != p and b != p
    assert client.post("/v1/auth/google/browser/poll", json={"token": b}).status_code == 401
    assert client.post("/v1/auth/google/browser/prepare", json={"token": p}).status_code == 401
    assert client.post("/v1/auth/google/browser/cancel", json={"token": p}).status_code == 204
    assert client.post("/v1/auth/google/browser/prepare", json={"token": b}).status_code == 401
    assert client.post("/v1/auth/google/browser/poll", json={"token": p}).status_code == 401


def test_handoff_expiration_cleanup_and_validation(browser):
    client, app = browser
    b, p = start(client)
    with app.state.session_factory() as session:
        session.execute(update(BrowserLogin).values(expires_at=now() - 1))
        session.commit()
    assert client.post("/v1/auth/google/browser/prepare", json={"token": b}).status_code == 401
    assert client.post("/v1/auth/google/browser/poll", json={"token": p}).status_code == 401
    assert cleanup(app.state.session_factory)["browser_logins"] == 1
    for name in ("", "   ", "x" * 41, "x\u202ey"):
        assert client.post("/v1/auth/google/browser/start", json={"display_name": name}).status_code == 422


def test_browser_no_credentials_in_page_and_safe_headers(browser, auth_client):
    client, _app = browser
    b, p = start(client)
    response = client.get("/v1/auth/google/browser")
    assert response.status_code == 200
    assert b not in response.text and p not in response.text
    assert "frame-ancestors 'none'" in response.headers["content-security-policy"]
    assert response.headers["cache-control"] == "no-store"
    assert auth_client.post("/v1/auth/google/browser/start", json={"display_name": "Name"}).status_code == 503


def test_fixed_developer_account_and_removal(auth_app, sign_in):
    google = sign_in("developer", display_name="My chosen name")
    settings = replace(
        auth_app.state.settings, environment="development", dev_auth_enabled=True, dev_auth_key="k" * 32
    )
    app = create_app(settings, engine=auth_app.state.engine)
    with TestClient(app) as client:
        assert client.post("/v1/auth/developer").status_code == 401
        first = client.post("/v1/auth/developer", headers={"X-Dev-Auth-Key": "k" * 32}).json()
        second = client.post("/v1/auth/developer", headers={"X-Dev-Auth-Key": "k" * 32}).json()
        assert first["player"] == second["player"]
        assert first["player"]["display_name"] == "developer"
        assert first["player"]["id"] != google["player"]["id"]
        headers = {"Authorization": "Bearer " + first["access_token"]}
        assert client.patch("/v1/me", headers=headers, json={"display_name": "renamed"}).status_code == 403
    with TestClient(auth_app) as client:
        assert client.get("/v1/bootstrap").json()["development_auth"] is False
        assert client.post("/v1/auth/developer", headers={"X-Dev-Auth-Key": "k" * 32}).status_code == 404
        assert client.get("/v1/me", headers=headers).status_code == 401
        assert (
            client.post("/v1/auth/refresh", json={"refresh_token": first["refresh_token"]}).status_code == 401
        )
        assert (
            client.get("/v1/me", headers={"Authorization": "Bearer " + google["access_token"]}).status_code
            == 200
        )
