"""Real authenticated appearance writes, shared standings, bounds and erasure."""
import copy
import json
import re
from pathlib import Path
from uuid import uuid4

import pytest
from test_domains import domain as _domain_fixture
from test_domains import headers
from test_rivalry import join, seed

from bmt_backend.identity_models import Player
from bmt_backend.privacy import redact_snapshot, remove_account
from bmt_backend.vehicle_appearance import CATALOG

rivalry_domain = _domain_fixture


def appearance(vehicle="compact", pattern="plain"):
    sticker = {"id": "none", "x": 0.5, "y": 0.5, "size": 0.62, "rotation": 0.0}
    return {"vehicle_id": vehicle, "livery": {"version": 2, "colors": {
        "body": "c94026", "accent": "e0d5b5", "detail": "c78e4c"}, "pattern": pattern,
        "stickers": {"hood": sticker.copy(), "roof": sticker.copy()}},
        "customisation": {"version": 1, "hood": "stock", "aero": "stock", "rims": "stock", "body": "stock"}}


def save(domain, value, player="Alice"):
    return domain.client.put("/v1/rivalry/appearance", json=value, headers=headers(domain, player))


def test_catalog_matches_native_assets():
    root = Path(__file__).resolve().parents[2]
    assert CATALOG["patterns"] == ["plain"] + [row["id"] for row in json.loads((root / "game/assets/liveries/catalog.json").read_text())]
    assert CATALOG["stickers"] == ["none"] + [row["id"] for row in json.loads((root / "game/assets/liveries/stickers.json").read_text())]
    source = (root / "game/vehicle/vehicle_customisation.gd").read_text()
    for category, ids in CATALOG["parts"].items():
        block = source.split('"' + category + '":[', 1)[1].split(']],', 1)[0].split(']]}', 1)[0]
        assert ids == re.findall(r'\["([a-z_]+)","', '[' + block)


def test_players_share_their_own_parts_and_livery_without_changing_scores(rivalry_domain):
    seed(rivalry_domain)
    first = join(rivalry_domain)
    join(rivalry_domain, "Bob")
    alice = appearance(pattern=CATALOG["patterns"][-1])
    alice["customisation"].update(hood="cowl", aero="splitwing", rims="mesh", body="wide")
    alice["livery"]["stickers"]["hood"].update(id=CATALOG["stickers"][-1], x=0.1, y=0.8, rotation=-97.0)
    bob = appearance(pattern=CATALOG["patterns"][1])
    bob["livery"]["colors"]["body"] = "136a94"
    assert save(rivalry_domain, alice).json() == alice
    assert save(rivalry_domain, bob, "Bob").json() == bob
    board = rivalry_domain.client.get(f"/v1/rivalry/{first['group_id']}", headers=headers(rivalry_domain, "Alice")).json()
    rows = {row["id"]: row for row in board["standings"]}
    assert rows[rivalry_domain.players["Alice"]]["appearance"] == alice
    assert rows[rivalry_domain.players["Bob"]]["appearance"] == bob
    assert all(row["rank"] is None and row["points"] == 0 for row in rows.values())
    assert all("appearance" not in row for track in board["tracks"] for row in track["entries"])
    assert all("appearance" not in item for item in board["tracks"])
    again = copy.deepcopy(alice)
    again["customisation"]["aero"] = "drag"
    assert save(rivalry_domain, again).json() == again
    assert save(rivalry_domain, appearance("pickup")).status_code == 200
    with rivalry_domain.factory() as session:
        assert session.get(Player, rivalry_domain.players["Alice"]).vehicle_appearances == {"compact": again, "pickup": appearance("pickup")}
    other = rivalry_domain.client.get(f"/v1/rivalry/{first['group_id']}", headers=headers(rivalry_domain, "Bob")).json()
    assert next(row for row in other["standings"] if row["id"] == rivalry_domain.players["Alice"])["appearance"] == again


@pytest.mark.parametrize("path,value", [
    (("vehicle_id",), "../compact"), (("player_id",), "another-player"), (("condition",), {"dirt": 1}),
    (("livery", "pattern"), "unknown"), (("livery", "colors", "body"), "ff0000ff"),
    (("livery", "colors", "body"), 30627), (("livery", "stickers", "hood", "id"), "https://example.com/a.png"),
    (("livery", "stickers", "hood", "x"), -0.001), (("livery", "stickers", "hood", "size"), 0.951),
    (("livery", "stickers", "hood", "rotation"), 181), (("livery", "stickers", "hood", "x"), "0.5"),
    (("customisation", "aero"), "arbitrary_mesh"), (("customisation", "version"), 2),
    (("livery", "version"), 1), (("vehicle_id",), "x" * 5000),
    (("customisation", "version"), True), (("livery", "version"), 2.0),
])
def test_untrusted_appearance_is_rejected(rivalry_domain, path, value):
    payload = appearance()
    target = payload
    for key in path[:-1]:
        target = target[key]
    target[path[-1]] = value
    assert save(rivalry_domain, payload).status_code == 422
    with rivalry_domain.factory() as session:
        assert session.get(Player, rivalry_domain.players["Alice"]).vehicle_appearances == {}


def test_all_allowed_assets_and_vehicle_bounds(rivalry_domain):
    for pattern in CATALOG["patterns"]:
        assert save(rivalry_domain, appearance(pattern=pattern)).status_code == 200
    for sticker in CATALOG["stickers"]:
        value = appearance()
        value["livery"]["stickers"]["hood"]["id"] = sticker
        assert save(rivalry_domain, value).status_code == 200
    for category, parts in CATALOG["parts"].items():
        for part in parts:
            value = appearance()
            value["customisation"][category] = part
            assert save(rivalry_domain, value).status_code == 200
    for vehicle in ("pickup", "classic", "formula", "kart"):
        value = appearance(vehicle)
        assert save(rivalry_domain, value).status_code == 200
        value["customisation"]["aero"] = "wing"
        assert save(rivalry_domain, value).status_code == 422


def test_authentication_and_deletion_clear_online_appearance(rivalry_domain):
    assert rivalry_domain.client.put("/v1/rivalry/appearance", json=appearance()).status_code == 401
    assert save(rivalry_domain, appearance()).status_code == 200
    pid = rivalry_domain.players["Alice"]
    with rivalry_domain.factory() as session:
        remove_account(session, pid, "a" * 64, str(uuid4()))
        session.commit()
        assert session.get(Player, pid).vehicle_appearances == {}
    assert save(rivalry_domain, appearance()).status_code == 401
    redacted = redact_snapshot({"id": pid, "name": "Alice", "points": 30, "appearance": appearance()}, pid)
    assert "appearance" not in redacted and redacted["points"] == 30
