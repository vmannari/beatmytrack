"""3x3 is one invitation with three independently budgeted pinned races."""
import json
import os
import secrets
from pathlib import Path

from sqlalchemy import select
from test_challenges import PosedVerifier, join, normal_run
from test_domains import domain as _domain_fixture
from test_domains import headers, submit
from test_rivalry import seed

from bmt_backend.challenge_models import Challenge, ChallengeStage, ChallengeStageMember
from bmt_backend.community_models import PlayerBlock
from bmt_backend.track_models import Track, TrackVersion
from bmt_backend.worker import process_one

series_domain = _domain_fixture


def create(d, versions, **extra):
    return d.client.post("/v1/challenges", json={"mode": "3x3", "version_id": versions[0],
        "version_ids": versions, "vehicle_id": "compact", "attempt_limit": 3, **extra}, headers=headers(d, "Alice"))


def race(d, code, stage, frames=20, key=None):
    issued = d.client.post(f"/v1/challenges/{code}/tickets?stage={stage}", headers=headers(d, "Bob", key))
    assert issued.status_code == 201, issued.text
    submit(d, issued.json(), "Bob", frames)
    assert process_one(d.app)
    result = d.client.get(f"/v1/challenge-results/{issued.json()['ticket_id']}", headers=headers(d, "Bob"))
    assert result.status_code == 200, result.text
    return issued.json(), result.json()


def test_independent_budgets_verified_total_and_single_invitation(series_domain):
    d = series_domain
    d.app.state.verifier = PosedVerifier()
    versions = seed(d, 3)
    response = create(d, versions)
    assert response.status_code == 201, response.text
    item = response.json()
    assert item["mode"] == "3x3" and len(item["stages"]) == 3
    assert [s["entry"]["version_id"] for s in item["stages"]] == versions
    code = item["code"]
    join(d, code)
    assert d.client.post(f"/v1/challenges/{code}/tickets", headers=headers(d, "Bob")).status_code == 422
    for index in range(3):
        issued, result = race(d, code, index, frames=20+index)
        assert issued["version_id"] == versions[index] and issued["attempts_remaining"] == 2
        own = next(r for r in result["challenge"]["standings"] if r["id"] == d.players["Bob"])
        assert own["completed_tracks"] == index+1
        assert own["ticks"] == (315 if index == 2 else None)
    # Slower results consume starts but never replace the best or the total.
    _, slower = race(d, code, 0, frames=40)
    assert not slower["outcome"]["improved"]
    _, faster = race(d, code, 0, frames=10)
    own = next(r for r in faster["challenge"]["standings"] if r["id"] == d.players["Bob"])
    assert own["ticks"] == 265 and own["rank"] == 1
    export = os.environ.get("BMT_SERIES_EXPORT")
    if export:
        Path(export).write_text(json.dumps(faster["challenge"], indent=2)+"\n", encoding="utf-8")
    assert d.client.post(f"/v1/challenges/{code}/tickets?stage=0", headers=headers(d, "Bob")).status_code == 409
    assert d.client.post(f"/v1/challenges/{code}/tickets?stage=1", headers=headers(d, "Bob")).status_code == 201
    with d.factory() as session:
        assert len(session.scalars(select(Challenge)).all()) == 1
        assert len(session.scalars(select(ChallengeStageMember)).all()) == 6
    # Legacy clients do not receive a format they cannot parse.
    assert d.client.get("/v1/challenges?folder=received", headers=headers(d, "Bob")).json()["items"] == []
    assert len(d.client.get("/v1/challenges?folder=received&series=1", headers=headers(d, "Bob")).json()["items"]) == 1
    assert "3 tracks" in d.client.get(f"/c/{code}").text


def test_atomic_validation_exact_opening_and_stage_retry(series_domain):
    d = series_domain
    d.app.state.verifier = PosedVerifier()
    versions = seed(d, 3)
    for bad in [versions[:2], [versions[0]]*3, [versions[1], versions[0], versions[2]]]:
        body = {"mode": "3x3", "version_id": versions[0], "version_ids": bad, "vehicle_id": "compact", "attempt_limit": 3}
        assert d.client.post("/v1/challenges", json=body, headers=headers(d, "Alice")).status_code == 422
    assert create(d, [versions[0], versions[1], "00000000-0000-0000-0000-000000000000"]).status_code == 404
    with d.factory() as session:
        assert session.scalars(select(Challenge)).all() == []
        assert session.scalars(select(ChallengeStage)).all() == []
    normal_run(d, versions[0], frames=10)
    ticket = d.client.post("/v1/run-tickets", json={"version_id": versions[0], "vehicle_id": "compact"}, headers=headers(d, "Alice")).json()
    assert create(d, versions, source_ticket_id=ticket["ticket_id"]).status_code == 409
    submit(d, ticket, "Alice", 30)
    assert process_one(d.app)
    item = create(d, versions, source_ticket_id=ticket["ticket_id"]).json()
    opening = item["stages"][0]
    assert opening["attempts_remaining"] == 2 and opening["standings"][0]["ticks"] == 150
    assert item["standings"][0]["ticks"] is None
    code = item["code"]
    join(d, code)
    key = secrets.token_hex(16)
    first = d.client.post(f"/v1/challenges/{code}/tickets?stage=2", headers=headers(d, "Bob", key))
    repeat = d.client.post(f"/v1/challenges/{code}/tickets?stage=2", headers=headers(d, "Bob", key))
    assert first.json() == repeat.json() and first.json()["attempts_remaining"] == 2
    # A later unavailable track fences the whole series, including join and race entry.
    with d.factory() as session:
        version = session.get(TrackVersion, versions[2])
        session.get(Track, version.track_id).hidden = True
        session.commit()
    assert d.client.get(f"/v1/challenges/{code}/me", headers=headers(d, "Bob")).status_code == 404
    assert d.client.post(f"/v1/challenges/{code}/tickets?stage=0", headers=headers(d, "Bob")).status_code == 404


def test_create_retry_and_cancellation(series_domain):
    d = series_domain
    d.app.state.verifier = PosedVerifier()
    versions = seed(d, 3)
    body = {"mode": "3x3", "version_id": versions[0], "version_ids": versions, "vehicle_id": "compact", "attempt_limit": 3}
    h = headers(d, "Alice", secrets.token_hex(16))
    one = d.client.post("/v1/challenges", json=body, headers=h)
    two = d.client.post("/v1/challenges", json=body, headers=h)
    assert one.status_code == 201 and one.json() == two.json()
    changed = {**body, "version_ids": [versions[0], versions[2], versions[1]]}
    assert d.client.post("/v1/challenges", json=changed, headers=h).status_code == 409
    code = one.json()["code"]
    join(d, code)
    assert d.client.post(f"/v1/challenges/{code}/cancel", headers=headers(d, "Alice")).status_code == 200
    for index in range(3):
        assert d.client.post(f"/v1/challenges/{code}/tickets?stage={index}", headers=headers(d, "Bob")).status_code == 410


def test_series_migration_is_additive(series_domain):
    d = series_domain
    from alembic import command

    from bmt_backend.migrate import configuration
    with d.factory() as session:
        assert session.scalars(select(ChallengeStage)).all() == []
    command.downgrade(configuration(d.app.state.engine), "0057_discovery_resource_guards")
    command.upgrade(configuration(d.app.state.engine), "head")


def test_every_stage_obeys_creator_blocks_and_discovery_authority(series_domain):
    d = series_domain
    d.app.state.verifier = PosedVerifier()
    versions = seed(d, 3)
    with d.factory() as session:
        last = session.get(TrackVersion, versions[2])
        session.get(Track, last.track_id).owner_id = d.players["Carol"]
        session.commit()
    item = create(d, versions).json()
    join(d, item["code"])
    with d.factory() as session:
        session.add(PlayerBlock(player_id=d.players["Bob"], blocked_id=d.players["Carol"]))
        session.commit()
    assert d.client.get(f"/v1/challenges/{item['code']}/me", headers=headers(d, "Bob")).status_code == 403
    assert d.client.post(f"/v1/challenges/{item['code']}/tickets?stage=0", headers=headers(d, "Bob")).status_code == 403
    visible = d.client.get("/v1/challenges?folder=received&series=1&mode=3x3", headers=headers(d, "Bob"))
    assert visible.status_code == 200 and visible.json()["items"] == []
