"""PB ceremony facts come from verification and remain scoped to player/week."""
from sqlalchemy import select
from test_domains import domain as _domain_fixture
from test_domains import headers, submit
from test_rivalry import join, rivalry_ticket, seed

from bmt_backend.rivalry_models import RivalryTicket
from bmt_backend.worker import process_one

rivalry_domain = _domain_fixture


def test_finale_personal_bests_verified_distinct_and_player_scoped(rivalry_domain, monkeypatch):
    seed(rivalry_domain)
    original = join(rivalry_domain)
    group = original["group_id"]
    join(rivalry_domain, "Bob")
    for frames, expected in [(20, True), (20, False), (25, False), (19, True)]:
        issued = rivalry_ticket(rivalry_domain, group)
        submit(rivalry_domain, issued, "Alice", frames=frames)
        queued = rivalry_domain.client.get(f"/v1/rivalry/{group}", headers=headers(rivalry_domain, "Alice")).json()
        assert queued["personal_best_slots"] == []
        assert process_one(rivalry_domain.app)
        outcome = rivalry_domain.client.get(f"/v1/rivalry/tickets/{issued['ticket_id']}/result", headers=headers(rivalry_domain, "Alice")).json()["outcome"]
        assert outcome["personal_best"] is expected
    issued = rivalry_ticket(rivalry_domain, group, "Bob", slot=1)
    submit(rivalry_domain, issued, "Bob", frames=15)
    assert process_one(rivalry_domain.app)
    monkeypatch.setattr("bmt_backend.rivalry.now", lambda: original["ends_at"])
    alice = rivalry_domain.client.get(f"/v1/rivalry/{group}", headers=headers(rivalry_domain, "Alice")).json()
    bob = rivalry_domain.client.get(f"/v1/rivalry/{group}", headers=headers(rivalry_domain, "Bob")).json()
    assert alice["state"] == "complete" and alice["personal_best_slots"] == [0]
    assert bob["personal_best_slots"] == [1]
    # Repeated reads never mint achievements or alter any stored race outcome.
    assert rivalry_domain.client.get(f"/v1/rivalry/{group}", headers=headers(rivalry_domain, "Alice")).json() == alice
    assert "clean_driving" not in alice


def test_historical_missing_pb_evidence_is_not_invented(rivalry_domain, monkeypatch):
    seed(rivalry_domain)
    original = join(rivalry_domain)
    group = original["group_id"]
    issued = rivalry_ticket(rivalry_domain, group)
    submit(rivalry_domain, issued, "Alice", frames=20)
    assert process_one(rivalry_domain.app)
    with rivalry_domain.factory() as session:
        ticket = session.get(RivalryTicket, issued["ticket_id"])
        ticket.outcome = {key: value for key, value in ticket.outcome.items() if key != "personal_best"}
        session.commit()
        before = session.scalars(select(RivalryTicket.outcome).where(RivalryTicket.group_id == group)).all()
    monkeypatch.setattr("bmt_backend.rivalry.now", lambda: original["ends_at"])
    value = rivalry_domain.client.get(f"/v1/rivalry/{group}", headers=headers(rivalry_domain, "Alice")).json()
    assert value["state"] == "complete" and value["personal_best_slots"] == []
    assert value["standings"][0]["points"] == 30
    with rivalry_domain.factory() as session:
        assert session.scalars(select(RivalryTicket.outcome).where(RivalryTicket.group_id == group)).all() == before
