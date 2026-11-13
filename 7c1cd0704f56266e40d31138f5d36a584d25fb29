"""The newspaper exposes only the featured driver's published car appearance."""
from test_domains import domain as domain_fixture
from test_domains import public_course, race
from test_news import get
from test_rivalry_appearance import appearance

from bmt_backend.identity_models import Player
from bmt_backend.track_models import Board

domain = domain_fixture


def test_feed_includes_only_live_actor_matching_car(domain):
    version, board_id = public_course(domain)
    with domain.factory() as session:
        vehicle = session.get(Board, board_id).vehicle_id
    paint = appearance(vehicle)
    with domain.factory() as session:
        actor = session.get(Player, domain.players["Alice"])
        actor.vehicle_appearances = {vehicle: paint, "unused": appearance("pickup")}
        session.commit()
    race(domain, version, "Alice", frames=20)
    records = [row for row in get(domain)["items"] if row["kind"] == "world_record"]
    assert records and all(row["appearance"] == paint for row in records)
    assert all("unused" not in row["appearance"] for row in records)

    with domain.factory() as session:
        actor = session.get(Player, domain.players["Alice"])
        actor.vehicle_appearances = {vehicle: {**paint, "vehicle_id": "pickup"}}
        session.commit()
    assert all("appearance" not in row for row in get(domain)["items"] if row["kind"] == "world_record")

    with domain.factory() as session:
        actor = session.get(Player, domain.players["Alice"])
        actor.vehicle_appearances = {vehicle: paint}
        actor.disabled = True
        session.commit()
    assert all("appearance" not in row for row in get(domain)["items"] if row["kind"] == "world_record")
