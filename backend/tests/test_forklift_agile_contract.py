"""Forklift's accepted tune has a separate, explicitly pinned race contract."""
from copy import deepcopy
from types import SimpleNamespace

from test_car_compatibility import VersionedVerifier, builds, issue
from test_domains import domain as domain_fixture
from test_domains import submit
from test_rivalry import seed

from bmt_backend.runs import board_manifest
from bmt_backend.track_models import Run, digest
from bmt_backend.worker import process_one

domain = domain_fixture

OLD = {"handling_version": "forklift-4",
       "config_hash": "495947f7424e92c8b14f69c1de5b3a05bb2ab0ce85c4898c0f858e73b3d35003"}
NEW = {"handling_version": "forklift-5",
       "config_hash": "35f199342d5fdc07471bb00bc4a39ae5c024fc08031fa5836610db5256e09d50"}


def test_forklift_tune_pins_tickets_and_separates_boards(domain):
    _, current = builds()
    assert current["vehicles"]["forklift"] == NEW
    old = deepcopy(current)
    old["vehicles"]["forklift"] = OLD
    domain.app.state.verifier = VersionedVerifier(old)
    old_version = seed(domain, 1)[0]
    response = issue(domain, old_version, "forklift")
    assert response.status_code == 201, response.text
    old_ticket = response.json()
    assert {key: old_ticket["manifest"][key] for key in OLD} == OLD
    queued = submit(domain, old_ticket, "Alice")

    domain.app.state.verifier.build = current
    assert issue(domain, old_version, "forklift").status_code == 409
    assert not process_one(domain.app)
    with domain.factory() as db:
        assert db.get(Run, queued["run_id"]).status == "queued"

    new_version = seed(domain, 1)[0]
    response = issue(domain, new_version, "forklift")
    assert response.status_code == 201, response.text
    assert {key: response.json()["manifest"][key] for key in NEW} == NEW

    # Compare the same track-version ID and content: the vehicle contract alone
    # changes the board digest, while another car's identity remains unchanged.
    old_track = SimpleNamespace(manifest={**old, "track_content_hash": "same-track"})
    new_track = SimpleNamespace(manifest={**current, "track_content_hash": "same-track"})
    def board_id(track, vehicle):
        return digest({"version_id": "same-version", **board_manifest(track, vehicle)})
    assert board_id(old_track, "forklift") != board_id(new_track, "forklift")
    assert board_id(old_track, "compact") == board_id(new_track, "compact")

    domain.app.state.verifier.build = old
    assert process_one(domain.app)
    with domain.factory() as db:
        assert db.get(Run, queued["run_id"]).status == "verified"
