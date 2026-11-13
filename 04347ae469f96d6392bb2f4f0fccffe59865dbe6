"""An Electric-only update must preserve other cars' actual competitive flows."""
import json
from copy import deepcopy
from dataclasses import replace
from pathlib import Path

import pytest
from sqlalchemy import func, select
from test_domains import FakeVerifier, headers, submit
from test_domains import domain as domain_fixture
from test_rivalry import join, rivalry_ticket, seed

from bmt_backend.contracts import current_manifest
from bmt_backend.publications import PublicationFailure, _check_contract
from bmt_backend.rivalry import eligible_query, week_window
from bmt_backend.rivalry_models import RivalryGroup, RivalryMember
from bmt_backend.rivalry_planning import maintain, plan_contract
from bmt_backend.track_models import Board, PersonalBest, Run, TrackVersion, now
from bmt_backend.worker import process_one

domain = domain_fixture


class VersionedVerifier(FakeVerifier):
    def __init__(self, build):
        self.build = deepcopy(build)

    def manifest(self):
        return deepcopy(self.build)

    def verify_run(self, *args, **kwargs):
        result = super().verify_run(*args, **kwargs)
        ticks = result["time_ticks"]
        result["ghost"] = {"ticks":ticks,"poses":[[0,0,0,0,0,0,0],[ticks,10,10,0,0,0,0]]}
        return result


def builds():
    current = current_manifest(json.loads((Path(__file__).parent / "fixtures/verified_oval.json").read_text())["expected_manifest"])
    previous = deepcopy(current)
    previous["physics_version"] = "arcade-planar-0.74"
    previous["vehicles"]["electric"] = {"handling_version":"electric-17",
        "config_hash":"4ce920bc320196a5556c6e11407b299aac6c2078fecd8ac221e5a4a612750359"}
    return previous, current


def issue(d, version_id, vehicle="compact", player="Alice"):
    return d.client.post("/v1/run-tickets",json={"version_id":version_id,"vehicle_id":vehicle},headers=headers(d,player))


@pytest.mark.parametrize("vehicle",["compact","pickup","classic","formula","kart","forklift","electric"])
@pytest.mark.parametrize("rollback",[False,True])
def test_car_update_preserves_original_ticket_board_pb_and_worker_execution(domain, vehicle, rollback):
    old, current = builds()
    if rollback:
        old, current = current, old
    domain.app.state.verifier = VersionedVerifier(old)
    version = seed(domain,1)[0]
    first = issue(domain,version,vehicle)
    assert first.status_code == 201, first.text
    first = first.json()
    queued = submit(domain,first,"Alice")
    domain.app.state.verifier.build = current
    reply = issue(domain,version,vehicle)
    if vehicle == "electric":
        assert reply.status_code == 409
        assert not process_one(domain.app)
        with domain.factory() as db:
            run = db.get(Run,queued["run_id"])
            assert run.status == "queued" and run.attempts == 0
        # The actual old cohort can still finish its own recording.
        domain.app.state.verifier.build = old
        assert process_one(domain.app)
        return
    assert reply.status_code == 201, reply.text
    assert reply.json()["board_id"] == first["board_id"]
    assert reply.json()["manifest"] == first["manifest"]
    assert process_one(domain.app)
    with domain.factory() as db:
        run = db.get(Run,queued["run_id"])
        assert run.status == "verified" and run.attempts == 1
        assert db.get(Board,first["board_id"]).manifest == first["manifest"]
        assert db.get(TrackVersion,version).manifest["physics_version"] == old["physics_version"]
        assert db.get(PersonalBest,(first["board_id"],domain.players["Alice"])).run_id == run.id


@pytest.mark.parametrize("field",["engine_version","compiler_version","rules_key","physics_version","config_hash"])
def test_unknown_or_selected_car_changes_still_require_the_matching_contract(domain, field):
    old, current = builds()
    domain.app.state.verifier = VersionedVerifier(old)
    version = seed(domain,1)[0]
    if field == "config_hash":
        current["vehicles"]["compact"][field] = "another-tune"
    else:
        current[field] += "-unknown"
    domain.app.state.verifier.build = current
    assert issue(domain,version).status_code == 409


def test_optional_and_unrelated_car_metadata_does_not_change_compact_contract(domain):
    old, current = builds()
    domain.app.state.verifier = VersionedVerifier(current)
    version = seed(domain,1)[0]
    first = issue(domain,version).json()
    metadata = deepcopy(current)
    metadata["vehicles"]["compact"]["future_optional_metadata"] = "ignored"
    metadata["vehicles"]["new-car"] = {"handling_version":"new-1","config_hash":"new"}
    metadata["vehicles"]["electric"] = old["vehicles"]["electric"]
    domain.app.state.verifier.build = metadata
    assert plan_contract(current,"compact") == plan_contract(metadata,"compact")
    reply = issue(domain,version)
    assert reply.status_code == 201, reply.text
    assert reply.json()["board_id"] == first["board_id"]
    with domain.factory() as db:
        assert [row.id for row in db.scalars(eligible_query(metadata,"compact"))] == [version]


@pytest.mark.parametrize("vehicle",["compact","pickup","classic","formula","kart","forklift"])
def test_future_electric_tune_keeps_every_unrelated_car_contract_exact(domain, vehicle):
    _old, current = builds()
    domain.app.state.verifier = VersionedVerifier(current)
    version = seed(domain,1)[0]
    first = issue(domain,version,vehicle).json()
    future = deepcopy(current)
    future["vehicles"]["electric"] = {"handling_version":"electric-19","config_hash":"future-electric-tune"}
    domain.app.state.verifier.build = future
    issued = issue(domain,version,vehicle)
    assert issued.status_code == 201, issued.text
    assert issued.json()["board_id"] == first["board_id"]
    assert issued.json()["manifest"] == first["manifest"]
    assert plan_contract(future,vehicle) == plan_contract(current,vehicle)
    queued = submit(domain,first,"Alice")
    assert process_one(domain.app)
    with domain.factory() as db:
        assert db.get(Run,queued["run_id"]).status == "verified"


def test_existing_public_challenge_remains_discoverable_joinable_and_verifiable(domain):
    old, current = builds()
    domain.app.state.verifier = VersionedVerifier(old)
    version = seed(domain,1)[0]
    first = issue(domain,version).json()
    source = submit(domain,first,"Alice")
    assert process_one(domain.app)
    created = domain.client.post("/v1/challenges",json={"version_id":version,"vehicle_id":"compact",
        "mode":"group","visibility":"public","source_run_id":source["run_id"]},headers=headers(domain,"Alice"))
    assert created.status_code == 201, created.text
    challenge = created.json()
    domain.app.state.verifier.build = current
    discovered = domain.client.get("/v1/challenges?folder=discover",headers=headers(domain,"Bob"))
    assert discovered.status_code == 200, discovered.text
    assert [row["id"] for row in discovered.json()["items"]] == [challenge["id"]]
    joined = domain.client.post(f"/v1/challenges/{challenge['code']}/join",headers=headers(domain,"Bob"))
    assert joined.status_code == 200, joined.text
    issued = domain.client.post(f"/v1/challenges/{challenge['code']}/tickets",headers=headers(domain,"Bob"))
    assert issued.status_code == 201, issued.text
    assert issued.json()["board_id"] == first["board_id"]
    queued = submit(domain,issued.json(),"Bob")
    assert process_one(domain.app)
    result = domain.client.get(f"/v1/runs/{queued['run_id']}",headers=headers(domain,"Bob"))
    assert result.json()["status"] == "verified"


@pytest.mark.parametrize("world_circuit",[False,True])
def test_weekly_membership_lineup_and_peer_group_survive_electric_only_release(domain, world_circuit):
    old, current = builds()
    domain.app.state.verifier = VersionedVerifier(old)
    if world_circuit:
        domain.app.state.settings = replace(domain.app.state.settings,world_ranking_launch_week=week_window(now())[0])
    seed(domain,5)
    maintain(domain.app)
    first = join(domain,"Alice")
    group_id = first["group_id"]
    with domain.factory() as db:
        group = db.get(RivalryGroup,group_id)
        original_tracks, original_key = deepcopy(group.tracks), group.contract_key
        assert bool(group.world_circuit_id) == world_circuit
    domain.app.state.verifier.build = current
    shown = domain.client.get("/v1/rivalry/current?vehicle_id=compact",headers=headers(domain,"Alice"))
    assert shown.status_code == 200 and shown.json()["group_id"] == group_id, shown.text
    assert join(domain,"Alice")["group_id"] == group_id
    assert join(domain,"Bob")["group_id"] == group_id
    issued = rivalry_ticket(domain,group_id,"Alice")
    queued = submit(domain,issued,"Alice")
    assert process_one(domain.app)
    with domain.factory() as db:
        group = db.get(RivalryGroup,group_id)
        assert group.tracks == original_tracks and group.contract_key == original_key
        assert db.scalar(select(func.count()).select_from(RivalryGroup)) == 1
        assert db.scalar(select(func.count()).select_from(RivalryMember)) == 2
        assert db.get(Run,queued["run_id"]).status == "verified"


def test_saved_creator_lap_uses_selected_car_equivalence_without_relabeling():
    old, current = builds()
    old["track_content_hash"] = current["track_content_hash"] = "same-track"
    for car in current["vehicles"]:
        contract = {**old,"config_hash":old["vehicles"][car]["config_hash"]}
        if car == "electric":
            with pytest.raises(PublicationFailure):
                _check_contract(contract,current,car)
        else:
            _check_contract(contract,current,car)
            assert contract["physics_version"] == "arcade-planar-0.74"
