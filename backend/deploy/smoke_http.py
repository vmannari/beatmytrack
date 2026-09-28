"""Real HTTP/canonical-worker check for an isolated development Compose project."""

from __future__ import annotations

import json
import secrets
import time
import urllib.error
import urllib.request
from pathlib import Path


def verify_http_flow(repository: Path, development_key: str) -> list[str]:
    fixture = json.loads((repository / "backend/tests/fixtures/verified_oval.json").read_text())

    def http(path, method="GET", body=None, token=None, expected=200, extra_headers=None):
        headers = {"Content-Type": "application/json", "Idempotency-Key": secrets.token_hex(16)}
        if token:
            headers["Authorization"] = "Bearer " + token
        headers.update(extra_headers or {})
        request = urllib.request.Request(
            "http://127.0.0.1:18087" + path,
            data=json.dumps(body).encode() if body is not None else None,
            headers=headers,
            method=method,
        )
        try:
            response = urllib.request.urlopen(request, timeout=100)
        except urllib.error.HTTPError as rejected:
            response = rejected
        with response:
            if response.status != expected:
                raise AssertionError(
                    f"{method} {path}: expected {expected}; got {response.status}; {response.read()[:300]!r}"
                )
            return json.loads(response.read())

    def verify_race(identity, version, replay, expected_status="verified"):
        token = identity["access_token"]
        ticket = http("/v1/run-tickets", "POST", {"version_id": version, "vehicle_id": "compact"}, token, 201)
        submitted = http("/v1/runs", "POST", {"ticket_id": ticket["ticket_id"], "replay": replay}, token, 202)
        deadline = time.monotonic() + 120
        while time.monotonic() < deadline:
            status = http("/v1/runs/" + submitted["run_id"], token=token)
            if status["status"] not in ("queued", "verifying"):
                assert status["status"] == expected_status, status
                return ticket, status
            time.sleep(0.5)
        raise AssertionError("Real canonical verification did not finish within smoke-test deadline")

    manifest = http("/v1/manifest")
    assert manifest["engine_version"] == (repository / "godot-version.txt").read_text().strip()
    owner, racer = [
        http(
            "/v1/auth/development",
            "POST",
            {"subject": subject, "display_name": subject},
            extra_headers={"X-Dev-Auth-Key": development_key},
        )
        for subject in ("SmokeCreator", "SmokeRacer")
    ]
    track = http(
        "/v1/tracks",
        "POST",
        {"name": "Container verification oval", "document": fixture["document"]},
        owner["access_token"],
        201,
    )
    version = track["version_id"]
    ticket, proof = verify_race(owner, version, fixture["replay"])
    assert proof["time_ticks"] == fixture["time_ticks"]
    published = http(f"/v1/track-versions/{version}/publish", "POST", {}, owner["access_token"])
    assert published["state"] == "published"
    assert http(f"/v1/track-versions/{version}/document") == fixture["document"]
    other_ticket, proof = verify_race(racer, version, fixture["replay"])
    assert other_ticket["board_id"] == ticket["board_id"] and proof["time_ticks"] == fixture["time_ticks"]
    rating = http(f"/v1/track-versions/{version}/rating", "PUT", {"score": 5}, racer["access_token"])
    assert rating["rating_count"] == 1 and rating["rating_average"] == 5
    rating = http(f"/v1/track-versions/{version}/rating", "PUT", {"score": 4}, racer["access_token"])
    assert rating["rating_count"] == 1 and rating["rating_average"] == 4
    http(f"/v1/track-versions/{version}/rating", "PUT", {"score": 5}, owner["access_token"], 403)
    tampered = {"schema": fixture["replay"]["schema"], "frames": fixture["replay"]["frames"][:-1]}
    verify_race(racer, version, tampered, expected_status="rejected")
    board = http("/v1/boards/" + ticket["board_id"])
    assert board["population"] == 2 and all(row["time_ticks"] == 12757 for row in board["items"])
    histogram = http("/v1/boards/" + ticket["board_id"] + "/histogram")
    assert sum(bucket["count"] for bucket in histogram["bins"]) == 2
    return [
        "Linux canonical creator proof, immutable publication/download, second racer PB, rating update and histogram passed",
        "Self-rating and truncated replay rejected; invalid replay never replaced PB",
    ]
