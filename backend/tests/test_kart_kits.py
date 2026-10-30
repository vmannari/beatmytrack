"""Kart cosmetics remain vehicle-scoped and require permanent account ownership."""
import copy
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


def test_kart_catalog_matches_native_and_has_separate_prices():
    source = (Path(__file__).resolve().parents[2] / "game/vehicle/vehicle_customisation.gd").read_text()
    source = source.split("const KART_OPTIONS:", 1)[1].split("const KART_DESCRIPTIONS:", 1)[0]
    for category, options in CATALOG["kart_parts"].items():
        block = source.split('"' + category + '":[', 1)[1].split(']],', 1)[0].split(']]}', 1)[0]
        assert options == re.findall(r'\["([a-z_]+)","', '[' + block)
        for option in options:
            item = f"kit/kart/{category}/{option}"
            assert item not in PRICES if option == "stock" else PRICES[item] == 750


@pytest.mark.parametrize("category,option", [(category, option) for category, options in CATALOG["kart_parts"].items() for option in options])
def test_kart_schema_and_vehicle_fences(category, option):
    value = appearance("kart")
    value["customisation"][category] = option
    assert Appearance.model_validate(value).model_dump() == value
    assert required_items(value) == (set() if option == "stock" else {f"kit/kart/{category}/{option}"})
    if option != "stock":
        for vehicle in ("compact", "pickup", "electric", "hovercraft"):
            if vehicle == "compact" and option in CATALOG["parts"][category]:
                continue
            value["vehicle_id"] = vehicle
            with pytest.raises(ValidationError):
                Appearance.model_validate(value)


def test_compact_parts_cannot_be_equipped_on_kart():
    value = appearance("kart")
    value["customisation"]["hood"] = "scoop"
    with pytest.raises(ValidationError):
        Appearance.model_validate(value)


def test_kart_purchase_sync_and_public_appearance_use_same_authority(domain):
    value = appearance("kart")
    value["customisation"]["hood"] = "sprint"
    assert put(domain, value).status_code == 403
    assert save(domain, value).status_code == 403
    assert read(domain).json() == {"appearances": {}}
    fund(domain, amount=1500, player="Alice")
    item = "kit/kart/hood/sprint"
    key = str(uuid4())
    purchase = domain.client.post("/v1/economy/purchases", json={"item_id": item, "expected_price": 750}, headers=headers(domain, "Alice", key))
    assert purchase.status_code == 200, purchase.text
    assert purchase.json()["charged"] == 750
    retry = domain.client.post("/v1/economy/purchases", json={"item_id": item, "expected_price": 750}, headers=headers(domain, "Alice", key))
    assert retry.json() == purchase.json()
    assert put(domain, value).json() == value
    assert save(domain, value).json() == value
    assert read(domain).json()["appearances"]["kart"] == value
    assert save(domain, value, "Bob").status_code == 403
    rejected = copy.deepcopy(value)
    rejected["customisation"]["rims"] = "disc"
    assert put(domain, rejected, value).status_code == 403
    assert read(domain).json()["appearances"]["kart"] == value
    assert domain.client.get("/v1/economy", headers=headers(domain, "Alice")).json()["balance"] == 750
