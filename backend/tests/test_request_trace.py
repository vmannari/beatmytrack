"""Real early boundary failures retain safe templates and generated correlation IDs."""
import json
import logging
import uuid

import pytest


@pytest.mark.parametrize("method,path,body,headers,status,template", [
    ("POST", "/v1/auth/google/browser/complete?token=private-query", b'{"private-body":',
     {"Content-Type": "application/json"}, 400, "/v1/auth/google/browser/complete"),
    ("POST", "/v1/track-versions/private-identifier/document?secret=private-query", b"private-body",
     {"Content-Type": "text/plain"}, 405, "/v1/track-versions/{version_id}/document"),
    ("POST", "/v1/publications?secret=private-query", b"{}",
     {"Content-Type": "application/json", "Content-Length": str(8*1024*1024+1)}, 413, "/v1/publications"),
    ("POST", "/not-a-route/private-identifier?secret=private-query", b'{"private-body":',
     {"Content-Type": "application/json"}, 400, "unmatched"),
])
def test_rejection_log_matches_only_template_and_own_request_id(auth_client, method, path, body, headers, status, template):
    rows = []
    class Capture(logging.Handler):
        def emit(self, record):
            if record.getMessage().startswith('{'):
                rows.append(json.loads(record.getMessage()))
    logger = logging.getLogger("bmt.requests")
    handler = Capture()
    logger.addHandler(handler)
    supplied = str(uuid.uuid4())
    try:
        response = auth_client.request(method, path, content=body,
                                       headers={**headers, "X-Request-ID": supplied, "Authorization": "Bearer private-access"})
    finally:
        logger.removeHandler(handler)
    assert response.status_code == status, response.text
    assert len(rows) == 1
    row = rows[0]
    identifier = response.headers["x-request-id"]
    assert str(uuid.UUID(identifier)) == identifier and identifier != supplied
    assert response.json()["request_id"] == row["request_id"] == identifier
    assert row["route"] == template
    assert row["status"] == status
    serialized = json.dumps(row)
    assert all(value not in serialized for value in ["private-identifier", "private-query", "private-body", "private-access", supplied])


def test_rate_limit_before_routing_keeps_template(auth_app, auth_client, monkeypatch):
    from bmt_backend.middleware import RequestBoundary
    async def denied(*_args, **_kwargs):
        return False
    monkeypatch.setattr(RequestBoundary, "peer_budget", denied)
    rows = []
    class Capture(logging.Handler):
        def emit(self, record):
            rows.append(json.loads(record.getMessage()))
    logger = logging.getLogger("bmt.requests")
    handler = Capture()
    logger.addHandler(handler)
    try:
        response = auth_client.get("/v1/runs/private-run-id?private-query=true")
    finally:
        logger.removeHandler(handler)
    assert response.status_code == 429
    assert rows[-1]["route"] == "/v1/runs/{run_id}"
    assert rows[-1]["request_id"] == response.headers["x-request-id"]
    assert "private" not in json.dumps(rows)


def test_nested_router_prefixes_and_normal_requests_use_same_safe_template(auth_app):
    from fastapi import APIRouter, Depends
    from fastapi.testclient import TestClient

    calls = []
    def dependency():
        calls.append("dependency")
    child = APIRouter()
    @child.get("/items/{item_id}", dependencies=[Depends(dependency)])
    def item(item_id: str):
        calls.append("endpoint")
        return {"ok": True}
    parent = APIRouter()
    parent.include_router(child, prefix="/nested")
    auth_app.include_router(parent, prefix="/diagnostics")
    rows = []
    class Capture(logging.Handler):
        def emit(self, record):
            if record.getMessage().startswith('{'):
                rows.append(json.loads(record.getMessage()))
    logger = logging.getLogger("bmt.requests")
    handler = Capture()
    logger.addHandler(handler)
    try:
        with TestClient(auth_app) as client:
            rejected = client.get("/diagnostics/nested/items/private-id", headers={"Content-Length": "40000"})
            assert rejected.status_code == 413
            assert calls == [], "Diagnostic route lookup called a dependency or endpoint"
            assert client.get("/diagnostics/nested/items/private-id").status_code == 200
    finally:
        logger.removeHandler(handler)
    assert calls == ["dependency", "endpoint"]
    assert [row["route"] for row in rows] == ["/diagnostics/nested/items/{item_id}"] * 2
    assert "private-id" not in json.dumps(rows)
