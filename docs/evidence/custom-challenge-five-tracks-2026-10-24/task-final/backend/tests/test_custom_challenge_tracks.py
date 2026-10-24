"""Custom selections cross creation, authoritative starts, verification and migrations."""
import json
import os
import secrets
from pathlib import Path

import pytest
from alembic import command
from sqlalchemy import select
from test_challenges import PosedVerifier, join, normal_run
from test_domains import domain as _domain_fixture
from test_domains import headers, submit
from test_rivalry import seed

from bmt_backend.challenge_models import Challenge, ChallengeStage, ChallengeStageMember
from bmt_backend.migrate import configuration
from bmt_backend.worker import process_one

custom_domain = _domain_fixture


def create(d, versions, **extra):
    return d.client.post("/v1/challenges", json={"mode":"group", "version_id":versions[0],
        "version_ids":versions, "vehicle_id":"compact", **extra}, headers=headers(d, "Alice"))


@pytest.mark.parametrize("count,limit", [(2,1), (3,3), (4,None), (5,5)])
def test_custom_counts_budgets_and_verified_totals(custom_domain, count, limit):
    d = custom_domain
    d.app.state.verifier = PosedVerifier()
    versions = seed(d, count)
    response = create(d, versions, attempt_limit=limit)
    assert response.status_code == 201, response.text
    item = response.json()
    assert item["track_count"] == count and len(item["stages"]) == count
    assert item["attempt_limit"] == (count*limit if limit else None)
    code = item["code"]
    join(d, code)
    total = 0
    for index in range(count):
        issued = d.client.post(f"/v1/challenges/{code}/tickets?stage={index}", headers=headers(d,"Bob"))
        assert issued.status_code == 201, issued.text
        ticket = issued.json()
        assert ticket["version_id"] == versions[index]
        assert ticket["attempts_remaining"] == (limit-1 if limit else None)
        submit(d, ticket, "Bob", 20+index)
        assert process_one(d.app)
        result = d.client.get(f"/v1/challenge-results/{ticket['ticket_id']}", headers=headers(d,"Bob")).json()
        assert result["outcome"]["stage_index"] == index
        own = next(row for row in result["challenge"]["standings"] if row["id"] == d.players["Bob"])
        total += (20+index)*5
        assert own["completed_tracks"] == index+1
        assert own["ticks"] == (total if index == count-1 else None)
        ghost = d.client.get(f"/v1/challenges/{code}/ghost?stage={index}")
        assert ghost.status_code == 200, ghost.text
    if count == 5:
        export = os.environ.get("BMT_CUSTOM_SERIES_EXPORT")
        if export:
            Path(export).write_text(json.dumps(result["challenge"],indent=2)+"\n",encoding="utf-8")
        # A fifth allowed start remains valid; the sixth is rejected on this track only.
        for attempt in range(4):
            key = secrets.token_hex(16)
            first = d.client.post(f"/v1/challenges/{code}/tickets?stage=4",headers=headers(d,"Bob",key))
            repeat = d.client.post(f"/v1/challenges/{code}/tickets?stage=4",headers=headers(d,"Bob",key))
            assert first.status_code == 201 and first.json() == repeat.json()
        assert d.client.post(f"/v1/challenges/{code}/tickets?stage=4",headers=headers(d,"Bob")).status_code == 409
        assert d.client.post(f"/v1/challenges/{code}/tickets?stage=3",headers=headers(d,"Bob")).status_code == 201
    if limit is None:
        for _ in range(6):
            assert d.client.post(f"/v1/challenges/{code}/tickets?stage=3",headers=headers(d,"Bob")).status_code == 201
    assert d.client.post(f"/v1/challenges/{code}/tickets?stage={count}",headers=headers(d,"Bob")).status_code == 422
    assert d.client.get("/v1/challenges?folder=received&series=1",headers=headers(d,"Bob")).json()["items"] == []
    assert len(d.client.get("/v1/challenges?folder=received&custom_tracks=1",headers=headers(d,"Bob")).json()["items"]) == 1
    assert f"{count} tracks" in d.client.get(f"/c/{code}").text


def test_custom_rejects_six_duplicates_and_reordered_opening_atomically(custom_domain):
    d = custom_domain
    d.app.state.verifier = PosedVerifier()
    versions = seed(d,6)
    for bad in [versions, versions[:1], [versions[0]]*5, [versions[1],versions[0]]]:
        body = {"mode":"group","version_id":versions[0],"version_ids":bad,"vehicle_id":"compact"}
        assert d.client.post("/v1/challenges",json=body,headers=headers(d,"Alice")).status_code == 422
    assert create(d, [*versions[:4],"00000000-0000-0000-0000-000000000000"]).status_code == 404
    with d.factory() as session:
        assert session.scalars(select(Challenge)).all() == []
        assert session.scalars(select(ChallengeStage)).all() == []


def test_two_person_series_preserves_source_and_creator_can_finish(custom_domain):
    d = custom_domain
    d.app.state.verifier = PosedVerifier()
    versions = seed(d,5)
    normal_run(d,versions[0],frames=30)
    item = create(d,versions,mode="beat",attempt_limit=1).json()
    assert item["capacity"] == 2 and item["stages"][0]["attempts_remaining"] == 0
    assert item["target_ticks"] is None and item["standings"][0]["ticks"] is None
    issued = d.client.post(f"/v1/challenges/{item['code']}/tickets?stage=4",headers=headers(d,"Alice"))
    assert issued.status_code == 201, issued.text
    assert issued.json()["version_id"] == versions[4]
    join(d,item["code"])
    assert d.client.post(f"/v1/challenges/{item['code']}/rematch",json={},headers=headers(d,"Alice")).status_code == 409


def test_stage_migration_preserves_existing_series_and_foreign_keys(custom_domain):
    d = custom_domain
    d.app.state.verifier = PosedVerifier()
    versions = seed(d,3)
    item = create(d,versions,mode="3x3",attempt_limit=3).json()
    join(d,item["code"])
    issued = d.client.post(f"/v1/challenges/{item['code']}/tickets?stage=2",headers=headers(d,"Bob"))
    assert issued.status_code == 201
    config = configuration(d.app.state.engine)
    command.downgrade(config,"0062_retire_discovery_cache")
    command.upgrade(config,"head")
    value = d.client.get(f"/v1/challenges/{item['code']}/me",headers=headers(d,"Bob")).json()
    assert value["track_count"] == 3 and value["stages"][2]["attempts_remaining"] == 2
    with d.factory() as session:
        assert len(session.scalars(select(ChallengeStageMember)).all()) == 6
    if not d.postgres:
        with d.app.state.engine.connect() as connection:
            assert connection.exec_driver_sql("PRAGMA foreign_keys").scalar() == 1
            assert connection.exec_driver_sql("PRAGMA foreign_key_check").all() == []
