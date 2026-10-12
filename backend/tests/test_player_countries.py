"""Profile country persistence, non-destructive migration and board propagation."""
import json
from dataclasses import replace
from pathlib import Path

import pytest
from alembic import command
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text
from test_domains import domain as _domain_fixture
from test_domains import headers, publish, race, submit, ticket, upload
from test_rivalry import join, rivalry_ticket, seed

from bmt_backend.app import create_app
from bmt_backend.countries import COUNTRY_CODES
from bmt_backend.countries import test_country as artificial_country
from bmt_backend.identity_models import Player
from bmt_backend.migrate import configuration, upgrade
from bmt_backend.worker import process_one

domain = _domain_fixture


def bearer(tokens):
    return {"Authorization": "Bearer " + tokens["access_token"]}


def test_country_catalog_matches_client_and_has_bundled_art():
    root = Path(__file__).resolve().parents[2]
    catalog = json.loads((root / "game/assets/countries/countries.json").read_text(encoding="utf-8"))
    assert {row["code"] for row in catalog} == COUNTRY_CODES
    assert len(COUNTRY_CODES) == 249
    for code in COUNTRY_CODES:
        assert (root / f"game/assets/countries/{code.lower()}.svg").is_file()


def test_country_only_patch_preserves_name_and_returns_on_login_and_refresh(auth_client, sign_in):
    tokens = sign_in("country-racer")
    assert tokens["player"]["country_code"] == ""
    result = auth_client.patch("/v1/me", headers=bearer(tokens), json={"country_code": "fi"})
    assert result.status_code == 200
    assert result.json()["country_code"] == "FI"
    assert result.json()["display_name"] == "country-racer"
    assert not result.json()["needs_username"]
    assert auth_client.get("/v1/me", headers=bearer(tokens)).json()["country_code"] == "FI"
    assert sign_in("country-racer")["player"]["country_code"] == "FI"
    refreshed = auth_client.post("/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert refreshed.status_code == 200 and refreshed.json()["player"]["country_code"] == "FI"
    result = auth_client.patch("/v1/me", headers=bearer(refreshed.json()), json={"display_name": "New racer"})
    assert result.status_code == 200 and result.json()["country_code"] == "FI"
    result = auth_client.patch("/v1/me", headers=bearer(refreshed.json()), json={"country_code": ""})
    assert result.status_code == 200 and result.json()["country_code"] == ""


@pytest.mark.parametrize("code", ["ZZ", "EU", "UK", "<b>", "en-US", "ＦＩ", "ß", None, True, 12])
def test_invalid_country_rejects_entire_profile_update(auth_client, sign_in, code):
    tokens = sign_in("unchanged")
    result = auth_client.patch("/v1/me", headers=bearer(tokens),
                               json={"display_name": "Should not persist", "country_code": code})
    assert result.status_code == 422
    player = auth_client.get("/v1/me", headers=bearer(tokens)).json()
    assert player["country_code"] == "" and player["display_name"] == "unchanged"


def test_country_is_authenticated_and_does_not_skip_username_step(auth_app, auth_client, sign_in):
    assert auth_client.patch("/v1/me", json={"country_code": "FI"}).status_code == 401
    tokens = sign_in()
    with auth_app.state.session_factory() as session:
        player = session.get(Player, tokens["player"]["id"])
        player.needs_username = True
        session.commit()
    result = auth_client.patch("/v1/me", headers=bearer(tokens), json={"country_code": "JP"})
    assert result.status_code == 200 and result.json()["needs_username"]
    assert auth_client.patch("/v1/me", headers=bearer(tokens), json={}).status_code == 422
    assert auth_client.patch("/v1/me", headers=bearer(tokens), json={"display_name": None}).status_code == 422


def test_developer_can_select_country_without_changing_fixed_name(auth_app):
    settings = replace(auth_app.state.settings, environment="development", dev_auth_enabled=True,
                       dev_auth_key="k" * 32)
    with TestClient(create_app(settings, engine=auth_app.state.engine)) as client:
        tokens = client.post("/v1/auth/developer", headers={"X-Dev-Auth-Key": "k" * 32}).json()
        result = client.patch("/v1/me", headers=bearer(tokens), json={"country_code": "CA"})
        assert result.status_code == 200 and result.json()["display_name"] == "Beat my track"
        denied = client.patch("/v1/me", headers=bearer(tokens), json={"display_name": "Changed", "country_code": "FI"})
        assert denied.status_code == 403
        assert client.get("/v1/me", headers=bearer(tokens)).json()["country_code"] == "CA"


def test_migration_keeps_real_identity_and_assigns_only_artificial_countries(tmp_path):
    engine = create_engine(f"sqlite:///{tmp_path / 'migration.sqlite'}")
    command.upgrade(configuration(engine), "0017_product_controls")
    with engine.begin() as connection:
        for player_id, synthetic in (("real-player", False), ("artificial-player", True)):
            connection.execute(text("INSERT INTO players (id,display_name,username_key,needs_username,disabled,"
                                    "is_test_driver,created_at) VALUES (:id,:id,:id,0,0,:synthetic,123)"),
                               {"id": player_id, "synthetic": synthetic})
    upgrade(engine)
    upgrade(engine)
    with engine.connect() as connection:
        rows = {row.id: row for row in connection.execute(text("SELECT * FROM players"))}
        assert rows["real-player"].country_code == ""
        assert rows["real-player"].display_name == "real-player" and rows["real-player"].created_at == 123
        assert rows["artificial-player"].country_code == artificial_country("artificial-player")
    engine.dispose()


def test_country_flows_through_public_neighbourhood_and_weekly_boards(domain):
    with domain.factory() as session:
        session.get(Player, domain.players["Alice"]).country_code = "FI"
        session.get(Player, domain.players["Bob"]).country_code = "BR"
        session.commit()
    version = upload(domain)
    race(domain, version, frames=30)
    publish(domain, version)
    for name, frames in (("Alice", 18), ("Bob", 20)):
        issued = ticket(domain, version, name)
        submit(domain, issued, name, frames=frames)
        assert process_one(domain.app)
    public = domain.client.get(f"/v1/track-versions/{version['version_id']}/leaderboard").json()
    assert [(row["display_name"], row["country_code"], row["rank"]) for row in public["items"]] == [
        ("Alice", "FI", 1), ("Bob", "BR", 2), ("Creator", "", 3)]
    nearby = domain.client.get(f"/v1/boards/{public['board_id']}/around-me", headers=headers(domain, "Alice")).json()
    assert nearby["player"]["country_code"] == "FI" and nearby["items"][1]["country_code"] == "BR"
    seed(domain)
    weekly = join(domain)
    join(domain, "Bob")
    issued = rivalry_ticket(domain, weekly["group_id"])
    submit(domain, issued, "Alice", frames=20)
    assert process_one(domain.app)
    result = domain.client.get(f"/v1/rivalry/tickets/{issued['ticket_id']}/result", headers=headers(domain, "Alice")).json()
    assert result["outcome"]["after"]["country_code"] == "FI"
    assert result["outcome"]["overall_after"]["country_code"] == "FI"
    current = domain.client.get(f"/v1/rivalry/{weekly['group_id']}", headers=headers(domain, "Alice")).json()
    expected = {domain.players["Alice"]: "FI", domain.players["Bob"]: "BR"}
    for rows in [current["standings"], *[slot["entries"] for slot in current["tracks"]]]:
        assert {row["id"]: row["country_code"] for row in rows} == expected
