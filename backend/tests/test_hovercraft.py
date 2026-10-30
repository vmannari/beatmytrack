"""The new selectable hull crosses cosmetics, telemetry and native packaging."""
import copy
import importlib.util
import json
from pathlib import Path

import pytest
from pydantic import ValidationError
from test_domains import domain as _domain_fixture
from test_domains import headers
from test_rivalry_appearance import appearance

from bmt_backend.achievements import CARS
from bmt_backend.telemetry import properties
from bmt_backend.vehicle_appearance import Appearance

domain = _domain_fixture
ROOT = Path(__file__).resolve().parents[2]


def test_hovercraft_private_appearance_survives_recovery(domain):
    value = appearance("hovercraft")
    route, auth = "/v1/me/appearances", headers(domain, "Alice")
    response = domain.client.put(route, headers=auth, json={"appearance": value, "previous": None})
    assert response.status_code == 200, response.text
    assert domain.client.get(route, headers=auth).json()["appearances"]["hovercraft"] == value
    assert domain.client.get(route, headers=headers(domain, "Bob")).json() == {"appearances": {}}
    changed = copy.deepcopy(value)
    changed["livery"]["colors"]["body"] = "698d87"
    update = {"appearance": changed, "previous": value}
    assert domain.client.put(route, headers=auth, json=update).status_code == 200
    assert domain.client.put(route, headers=auth, json=update).status_code == 200
    assert domain.client.put(route, headers=auth, json={"appearance": value, "previous": value}).status_code == 409


def test_hovercraft_rejects_car_only_parts():
    value = appearance("hovercraft")
    assert Appearance.model_validate(value).vehicle_id == "hovercraft"
    value["customisation"]["hood"] = "scoop"
    with pytest.raises(ValidationError, match="Compact only"):
        Appearance.model_validate(value)


def test_roster_addition_keeps_historical_cosmetics_and_achievement_positions():
    assert properties("car_selected", {"car_id": "hovercraft", "position": 5})["car_id"] == "hovercraft"
    assert CARS.index("classic") == 2 and CARS.index("formula") == 3 and CARS.index("hovercraft") == 7
    for vehicle in ("classic", "formula"):
        assert Appearance.model_validate(appearance(vehicle)).vehicle_id == vehicle
    schema = json.loads((ROOT / "backend/schemas/vehicle-appearance-sync-v1.schema.json").read_text())
    assert "hovercraft" in schema["$defs"]["Appearance"]["properties"]["vehicle_id"]["enum"]


def test_staged_verifier_includes_hovercraft_handling(tmp_path):
    spec = importlib.util.spec_from_file_location("stage_hovercraft", ROOT / "backend/deploy/stage_verifier.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    destination = tmp_path / "game"
    module.stage(ROOT, destination)
    assert (destination / "resources/cars/hovercraft.tres").read_bytes() == (ROOT / "game/resources/cars/hovercraft.tres").read_bytes()
    assert (destination / "vehicle/vehicle_simulation.gd").read_bytes() == (ROOT / "game/vehicle/vehicle_simulation.gd").read_bytes()
