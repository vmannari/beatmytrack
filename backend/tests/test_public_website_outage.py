"""The public information pages retain a bounded outage-only backstop."""
from dataclasses import replace

from fastapi.testclient import TestClient
from sqlalchemy.exc import SQLAlchemyError

from bmt_backend.app import create_app
from bmt_backend.public_pages import ASSETS


def test_public_pages_remain_readable_without_opening_api_routes(auth_client, monkeypatch):
    calls = []

    def unavailable(*args, **kwargs):
        calls.append(1)
        raise SQLAlchemyError("simulated outage")

    monkeypatch.setattr("bmt_backend.middleware.check_budget", unavailable)
    paths = ["/", "/privacy", "/account-deletion", "/community-rules",
             "/privacy/style.css", "/privacy/deletion.js"]
    paths.extend("/site/" + name for name in ASSETS)
    for path in paths:
        response = auth_client.get(path)
        assert response.status_code == 200, (path, response.text)
        assert response.headers["x-content-type-options"] == "nosniff"
    assert len(calls) == 1  # short circuit avoids hammering an unavailable database

    for method, path, headers in [
        ("GET", "/v1/me", {}),
        ("POST", "/v1/privacy/web-delete", {}),
        ("GET", "/", {"Authorization": "Bearer untrusted"}),
        ("GET", "/site/.env", {}),
        ("POST", "/", {}),
    ]:
        response = auth_client.request(method, path, headers=headers)
        assert response.status_code == 503, (method, path, response.text)
        assert response.json()["detail"] == "DATABASE_UNAVAILABLE"

    # Existing request-body protections still apply to outage-fallback pages.
    response = auth_client.request("GET", "/", content=b"unexpected")
    assert response.status_code == 400
    assert response.json()["detail"] == "REQUEST_BODY_NOT_ALLOWED"


def test_outage_fallback_retains_a_per_peer_budget(auth_app, monkeypatch):
    from bmt_backend import middleware

    shared_budget = middleware.check_budget

    def unavailable(*args, **kwargs):
        raise SQLAlchemyError("simulated outage")

    monkeypatch.setattr("bmt_backend.middleware.check_budget", unavailable)
    settings = replace(auth_app.state.settings, rate_limit_per_minute=2)
    app = create_app(settings, engine=auth_app.state.engine)
    try:
        with TestClient(app) as client:
            assert client.get("/").status_code == 200
            assert client.get("/privacy").status_code == 200
            denied = client.get("/account-deletion")
            assert denied.status_code == 429
            assert denied.json()["detail"] == "RATE_LIMITED"
            assert denied.headers["retry-after"] == "60"

            boundary = app.middleware_stack
            while not isinstance(boundary, middleware.RequestBoundary):
                boundary = boundary.app
            # Rotating peers cannot evade the independent per-process ceiling.
            assert all(boundary.public_fallback_budget(f"peer-{i}") for i in range(58))
            assert not boundary.public_fallback_budget("one-more-peer")
            boundary.public_fallback_window -= 1
            assert boundary.public_fallback_budget("one-more-peer")

            # Once the retry interval expires, the normal shared limiter is used.
            boundary.public_fallback_until = 0
            monkeypatch.setattr(middleware, "check_budget", shared_budget)
            assert client.get("/").status_code == 200
    finally:
        app.state.engine.dispose()
