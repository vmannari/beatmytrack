"""Forklift kits are vehicle-scoped and require ownership."""
from uuid import uuid4

import pytest
from pydantic import ValidationError
from test_appearance_sync import put, read
from test_domains import domain as _domain_fixture
from test_domains import headers
from test_earned_coins import fund
from test_rivalry_appearance import appearance

from bmt_backend.appearance_authorization import required_items
from bmt_backend.economy import PRICES
from bmt_backend.vehicle_appearance import CATALOG, Appearance

domain = _domain_fixture


@pytest.mark.parametrize("category,option", [(c, o) for c, options in CATALOG["forklift_parts"].items() for o in options])
def test_forklift_parts(category, option):
    value = appearance("forklift")
    value["customisation"][category] = option
    assert Appearance.model_validate(value).model_dump() == value
    item = f"kit/forklift/{category}/{option}"
    assert required_items(value) == (set() if option == "stock" else {item})
    if option != "stock":
        assert PRICES[item] == 750
        value["vehicle_id"] = "kart"
        with pytest.raises(ValidationError):
            Appearance.model_validate(value)


@pytest.mark.parametrize("category,option", [("hood", "fork_vent"), ("body", "fork_canopy"), ("rims", "fork_star"), ("aero", "fork_tow")])
def test_forklift_purchase_and_sync(domain, category, option):
    value = appearance("forklift")
    value["customisation"][category] = option
    assert put(domain, value).status_code == 403
    fund(domain, amount=750, player="Alice")
    purchase = domain.client.post(
        "/v1/economy/purchases",
        json={"item_id": f"kit/forklift/{category}/{option}", "expected_price": 750},
        headers=headers(domain, "Alice", str(uuid4())),
    )
    assert purchase.status_code == 200
    assert put(domain, value).json() == value
    assert read(domain).json()["appearances"]["forklift"] == value
