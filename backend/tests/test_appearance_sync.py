"""Private multi-device garage recovery, compare-and-swap and existing erasure."""
import copy
from concurrent.futures import ThreadPoolExecutor
from uuid import uuid4

import pytest
from test_domains import domain as _domain_fixture
from test_domains import headers
from test_rivalry_appearance import appearance

from bmt_backend.identity_models import Player
from bmt_backend.privacy import remove_account

domain = _domain_fixture


def put(d, value, previous=None, player="Alice"):
    return d.client.put("/v1/me/appearances", headers=headers(d, player),
                        json={"appearance": value, "previous": previous})


def read(d, player="Alice"):
    return d.client.get("/v1/me/appearances", headers=headers(d, player))


def test_private_five_car_recovery_and_independent_devices(domain):
    assert read(domain).json() == {"appearances": {}}
    from bmt_backend.economy_models import CosmeticUnlock
    with domain.factory() as session:
        for item in ("kit/compact/body/wide", "kit/compact/hood/scoop"):
            session.add(CosmeticUnlock(player_id=domain.players["Alice"], item_id=item, price=0))
        session.commit()
    saved = {}
    for vehicle in ("compact", "pickup", "classic", "formula", "kart"):
        value = appearance(vehicle)
        if vehicle == "compact":
            value["customisation"]["body"] = "wide"
            value["livery"]["stickers"]["roof"].update(id="crest", rotation=77.0)
        assert put(domain, value).status_code == 200
        saved[vehicle] = value
    assert read(domain).json() == {"appearances": saved}
    assert read(domain, "Bob").json() == {"appearances": {}}
    old = saved["compact"]
    changed = copy.deepcopy(old)
    changed["livery"]["colors"]["body"] = "112233"
    assert put(domain, changed, old).json() == changed
    assert put(domain, changed, old).json() == changed  # Lost reply, same operation.
    stale = copy.deepcopy(old)
    stale["customisation"]["hood"] = "scoop"
    assert put(domain, stale, old).status_code == 409
    saved["compact"] = changed
    assert read(domain).json() == {"appearances": saved}


def test_existing_rivalry_snapshot_and_concurrent_legacy_write(domain):
    old = appearance()
    assert domain.client.put("/v1/rivalry/appearance", headers=headers(domain, "Alice"), json=old).status_code == 200
    assert read(domain).json()["appearances"]["compact"] == old
    changed = copy.deepcopy(old)
    changed["livery"]["colors"]["body"] = "123456"
    assert put(domain, changed).status_code == 409
    assert put(domain, changed, old).status_code == 200
    assert domain.client.put("/v1/rivalry/appearance", headers=headers(domain, "Alice"), json=old).status_code == 200
    assert put(domain, changed, changed).status_code == 409


@pytest.mark.parametrize("field,value", [
    ("vehicle_id", "unknown"), ("condition", {}), ("balance", 99999),
    ("livery", {"version": 1}),
])
def test_invalid_appearance_never_changes_account(domain, field, value):
    body = appearance()
    body[field] = value
    assert put(domain, body).status_code == 422
    assert read(domain).json() == {"appearances": {}}


def test_auth_vehicle_scope_and_erasure(domain):
    assert domain.client.get("/v1/me/appearances").status_code == 401
    assert domain.client.put("/v1/me/appearances", json={"appearance": appearance(), "previous": None}).status_code == 401
    assert put(domain, appearance(), appearance("kart")).status_code == 422
    assert put(domain, appearance()).status_code == 200
    with domain.factory() as session:
        remove_account(session, domain.players["Alice"], "a" * 64, str(uuid4()))
        session.commit()
    assert put(domain, appearance()).status_code == 401
    assert read(domain).status_code == 401
    with domain.factory() as session:
        assert session.get(Player, domain.players["Alice"]).vehicle_appearances == {}


def test_simultaneous_devices_accept_one_same_car_write(auth_client, sign_in):
    # The auth fixture uses file-backed SQLite, with independent connections.
    login = sign_in(analytics=False)
    auth = {"Authorization": "Bearer " + login["access_token"]}
    original = appearance()
    assert auth_client.put("/v1/me/appearances", headers=auth,
                           json={"appearance": original, "previous": None}).status_code == 200
    versions = [copy.deepcopy(original), copy.deepcopy(original)]
    for value, colour in zip(versions, ("112233", "aabbcc"), strict=True):
        value["livery"]["colors"]["body"] = colour

    def write(value):
        return auth_client.put("/v1/me/appearances", headers=auth,
                               json={"appearance": value, "previous": original})

    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(write, versions))
    assert sorted(row.status_code for row in responses) == [200, 409]
    winner = next(row.json() for row in responses if row.status_code == 200)
    assert auth_client.get("/v1/me/appearances", headers=auth).json() == {"appearances": {"compact": winner}}
