"""Volt parts remain scoped to the car and require server-owned purchases."""
import re
from pathlib import Path
from uuid import uuid4

import pytest
from pydantic import ValidationError
from test_appearance_sync import put, read
from test_domains import domain as _domain_fixture
from test_domains import headers
from test_earned_coins import fund
from test_rivalry_appearance import appearance, save

from bmt_backend.appearance_authorization import required_items
from bmt_backend.economy import PRICES
from bmt_backend.vehicle_appearance import CATALOG, Appearance

domain = _domain_fixture


def test_electric_catalog_matches_native():
    source = (Path(__file__).resolve().parents[2] / "game/vehicle/vehicle_customisation.gd").read_text()
    source = source.split("const ELECTRIC_OPTIONS:", 1)[1].split("const ELECTRIC_DESCRIPTIONS:", 1)[0]
    for category, options in CATALOG["electric_parts"].items():
        block = source.split('"' + category + '":[', 1)[1].split(']]', 1)[0]
        assert options == re.findall(r'\["([a-z_]+)","', '[' + block)
        assert len(options) == 16
        for option in options:
            item = f"kit/electric/{category}/{option}"
            assert item not in PRICES if option == "stock" else PRICES[item] == 750


@pytest.mark.parametrize("category,option", [(c, o) for c, values in CATALOG["electric_parts"].items() for o in values])
def test_electric_parts_are_scoped_and_owned(category, option):
    value = appearance("electric")
    value["customisation"][category] = option
    assert Appearance.model_validate(value).model_dump() == value
    assert required_items(value) == (set() if option == "stock" else {f"kit/electric/{category}/{option}"})
    if option != "stock":
        for vehicle in ("compact", "kart", "pickup", "hovercraft", "forklift"):
            value["vehicle_id"] = vehicle
            with pytest.raises(ValidationError):
                Appearance.model_validate(value)


def test_electric_purchase_and_sync(domain):
    value = appearance("electric")
    value["customisation"]["hood"] = "volt_triple"
    assert put(domain, value).status_code == 403
    assert save(domain, value).status_code == 403
    fund(domain, amount=1500, player="Alice")
    item = "kit/electric/hood/volt_triple"
    key = str(uuid4())
    payload = {"item_id": item, "expected_price": 750}
    purchase = domain.client.post("/v1/economy/purchases", json=payload, headers=headers(domain, "Alice", key))
    assert purchase.status_code == 200, purchase.text
    assert domain.client.post("/v1/economy/purchases", json=payload, headers=headers(domain, "Alice", key)).json() == purchase.json()
    assert put(domain, value).json() == value
    assert save(domain, value).json() == value
    assert read(domain).json()["appearances"]["electric"] == value
