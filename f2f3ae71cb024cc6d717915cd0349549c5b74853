"""Super rally stays distinct in competition/saves and shares Rally cosmetic authority."""
import pytest
from pydantic import ValidationError
from test_appearance_sync import domain, put, read  # noqa: F401
from test_rivalry_appearance import appearance

from bmt_backend.appearance_authorization import required_items
from bmt_backend.economy_models import CosmeticUnlock
from bmt_backend.vehicle_appearance import Appearance
from bmt_backend.world_ranking_car_rules import CARS, PLAYABLE_CARS


def test_new_identity_and_shared_rally_parts():
    value = appearance("super_rally")
    value["customisation"].update(hood="scoop", body="wide")
    model = Appearance.model_validate(value)
    assert model.vehicle_id == "super_rally"
    assert required_items(model) == {"kit/compact/hood/scoop", "kit/compact/body/wide"}
    value["customisation"]["hood"] = "fork_dome"
    with pytest.raises(ValidationError):
        Appearance.model_validate(value)
    assert CARS[-1] == PLAYABLE_CARS[-1] == "super_rally"
    assert len(CARS) == len(set(CARS))


def test_independent_saved_appearances_and_existing_kit_ownership(domain):  # noqa: F811
    rally = appearance("compact")
    sport = appearance("super_rally")
    sport["livery"]["colors"]["body"] = "b73528"
    sport["customisation"]["hood"] = "scoop"
    assert put(domain, rally).status_code == 200
    assert put(domain, sport).status_code == 403
    with domain.factory() as session:
        session.add(CosmeticUnlock(player_id=domain.players["Alice"],
                                   item_id="kit/compact/hood/scoop", price=0))
        session.commit()
    assert put(domain, sport).status_code == 200
    assert read(domain).json() == {"appearances": {"compact": rally, "super_rally": sport}}
