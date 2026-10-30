"""Electric identity crosses the existing private cosmetics and observation boundaries."""
import copy
import json
from pathlib import Path

import pytest
from pydantic import ValidationError
from test_domains import domain as _domain_fixture
from test_domains import headers
from test_rivalry_appearance import appearance

from bmt_backend.achievements import CARS as ACHIEVEMENT_CARS
from bmt_backend.telemetry import properties
from bmt_backend.vehicle_appearance import Appearance

domain = _domain_fixture


def test_electric_private_recovery_and_compare_and_swap(domain):
    value = appearance("electric")
    route = "/v1/me/appearances"
    auth = headers(domain, "Alice")
    response = domain.client.put(route, headers=auth, json={"appearance": value, "previous": None})
    assert response.status_code == 200, response.text
    assert domain.client.get(route, headers=auth).json()["appearances"]["electric"] == value
    assert domain.client.get(route, headers=headers(domain, "Bob")).json() == {"appearances": {}}
    changed = copy.deepcopy(value)
    changed["livery"]["colors"]["body"] = "638d86"
    update = {"appearance": changed, "previous": value}
    assert domain.client.put(route, headers=auth, json=update).status_code == 200
    assert domain.client.put(route, headers=auth, json=update).status_code == 200
    assert domain.client.put(route, headers=auth, json={"appearance": value, "previous": value}).status_code == 409


def test_electric_parts_still_require_supported_fitment():
    value = appearance("electric")
    assert Appearance.model_validate(value).vehicle_id == "electric"
    value["customisation"]["hood"] = "scoop"
    with pytest.raises(ValidationError, match="Compact only"):
        Appearance.model_validate(value)


def test_electric_observations_and_progression_use_known_id():
    assert properties("car_selected", {"car_id": "electric", "position": 6})["car_id"] == "electric"
    assert "electric" in ACHIEVEMENT_CARS
    schema = json.loads((Path(__file__).resolve().parents[1] / "schemas/vehicle-appearance-sync-v1.schema.json").read_text())
    assert "electric" in schema["$defs"]["Appearance"]["properties"]["vehicle_id"]["enum"]
