"""One finale action advances across missed weeks without changing race results."""
import pytest
from sqlalchemy import select
from test_domains import domain as _domain_fixture
from test_domains import headers, submit
from test_rivalry import join, rivalry_ticket, seed

from bmt_backend.rivalry import week_window
from bmt_backend.rivalry_models import RivalryGroup, RivalryMember
from bmt_backend.track_models import now
from bmt_backend.worker import process_one

rivalry_domain = _domain_fixture


def current(domain, player="Alice"):
    response = domain.client.get("/v1/rivalry/current?vehicle_id=compact", headers=headers(domain, player))
    assert response.status_code == 200, response.text
    return response.json()


@pytest.mark.parametrize("older_group_created_later", [False, True])
def test_finale_uses_latest_membership_when_builds_changed_in_the_same_week(
        rivalry_domain, monkeypatch, older_group_created_later):
    seed(rivalry_domain)
    timestamp = now()
    monkeypatch.setattr("bmt_backend.rivalry.now", lambda: timestamp)
    latest = join(rivalry_domain)
    empty = {"group_id": "00000000-0000-4000-8000-000000000001"}
    alice = rivalry_domain.players["Alice"]
    # Preserve an earlier build's empty membership. Its contract sorts
    # first in the week index, reproducing the cloud's obsolete finale choice.
    with rivalry_domain.factory() as session:
        source = session.get(RivalryGroup, latest["group_id"])
        group = RivalryGroup(id=empty["group_id"], week_start=source.week_start,
            ends_at=source.ends_at, vehicle_id=source.vehicle_id, contract_key="f" * 64,
            skill_band=source.skill_band, tracks=source.tracks, member_count=1,
            created_at=timestamp + (200 if older_group_created_later else 0))
        session.add(group)
        session.flush()
        session.add(RivalryMember(group_id=group.id, player_id=alice,
            week_start=group.week_start, contract_key=group.contract_key, joined_at=timestamp))
        source.created_at = timestamp + 100
        session.get(RivalryMember, (source.id, alice)).joined_at = timestamp + 100
        session.commit()
    timestamp += 100
    assert latest["group_id"] != empty["group_id"]
    join(rivalry_domain, "Bob")
    issued = rivalry_ticket(rivalry_domain, latest["group_id"], "Bob")
    submit(rivalry_domain, issued, "Bob", frames=20)
    assert process_one(rivalry_domain.app)
    verified = current(rivalry_domain)
    assert verified["group_id"] == latest["group_id"]
    assert next(row for row in verified["standings"] if row["name"] == "Bob")["points"] == 30

    timestamp = latest["ends_at"]
    finale = current(rivalry_domain)
    assert finale["group_id"] == latest["group_id"]
    assert finale["state"] == "complete"
    assert finale["standings"] == verified["standings"]
    assert finale["tracks"] == verified["tracks"]
    # Direct history reads retain their exact separate championship identities.
    historical = rivalry_domain.client.get(f"/v1/rivalry/{empty['group_id']}",
        headers=headers(rivalry_domain, "Alice")).json()
    assert all(row["points"] == 0 for row in historical["standings"])
    assert all(row["ticks"] is None for track in historical["tracks"] for row in track["entries"])
    assert rivalry_domain.client.get(f"/v1/rivalry/{latest['group_id']}",
        headers=headers(rivalry_domain, "Alice")).json() == finale
    response = rivalry_domain.client.post(f"/v1/rivalry/{latest['group_id']}/continue",
        json={}, headers=headers(rivalry_domain, "Alice"))
    assert response.status_code == 200
    assert current(rivalry_domain)["state"] == "not_joined"
    with rivalry_domain.factory() as session:
        assert all(session.get(RivalryMember, (item["group_id"], alice)).acknowledged
                   for item in (empty, latest))


def test_continue_skips_all_older_finales_with_scoped_idempotency(rivalry_domain, monkeypatch):
    seed(rivalry_domain)
    timestamp = week_window(1791763200)[0] + 3600
    monkeypatch.setattr("bmt_backend.rivalry.now", lambda: timestamp)
    histories = []
    for _ in range(3):
        histories.append(join(rivalry_domain))
        join(rivalry_domain, "Bob")
        timestamp += 7 * 86400
    latest = histories[-1]
    assert current(rivalry_domain)["group_id"] == latest["group_id"]
    url = f"/v1/rivalry/{latest['group_id']}/continue"
    request_headers = headers(rivalry_domain, "Alice", "continue-missed-weeks")
    denied = rivalry_domain.client.post(url, json={}, headers=headers(rivalry_domain, "Carol"))
    assert denied.status_code == 404
    first = rivalry_domain.client.post(url, json={}, headers=request_headers)
    retry = rivalry_domain.client.post(url, json={}, headers=request_headers)
    assert first.status_code == retry.status_code == 200
    assert first.json() == retry.json() == {"acknowledged": True}
    assert current(rivalry_domain)["state"] == "not_joined"
    assert current(rivalry_domain, "Bob")["group_id"] == latest["group_id"]
    with rivalry_domain.factory() as session:
        members = session.scalars(select(RivalryMember).where(RivalryMember.player_id == rivalry_domain.players["Alice"])).all()
        assert len(members) == 3 and all(member.acknowledged for member in members)
        # Another car and population remain independent even for this player.
        source = session.get(RivalryGroup, latest["group_id"])
        for car, test in [("kart", False), ("compact", True)]:
            group = RivalryGroup(week_start=source.week_start, ends_at=source.ends_at,
                vehicle_id=car, test_population=test, contract_key=f"scope-{car}-{test}",
                skill_band=-1, tracks=source.tracks, member_count=1)
            session.add(group)
            session.flush()
            session.add(RivalryMember(group_id=group.id, player_id=rivalry_domain.players["Alice"],
                week_start=group.week_start, contract_key=group.contract_key))
        session.commit()
    # A new key remains safe, and never acknowledges the new week's membership.
    active = join(rivalry_domain)
    assert active["state"] == "active" and active["group_id"] not in [item["group_id"] for item in histories]
    assert rivalry_domain.client.post(url, json={}, headers=headers(rivalry_domain, "Alice")).status_code == 200
    assert current(rivalry_domain)["group_id"] == active["group_id"]
    with rivalry_domain.factory() as session:
        unacknowledged = session.scalars(select(RivalryMember).where(
            RivalryMember.player_id == rivalry_domain.players["Alice"], RivalryMember.acknowledged.is_(False))).all()
        assert len(unacknowledged) == 3  # Current, other car, other population.
    for history in histories:
        retained = rivalry_domain.client.get(f"/v1/rivalry/{history['group_id']}", headers=headers(rivalry_domain, "Alice"))
        assert retained.status_code == 200 and retained.json()["state"] == "complete"


def test_week_boundary_waits_for_verification_then_continues_once(rivalry_domain, monkeypatch):
    seed(rivalry_domain)
    original = join(rivalry_domain)
    url = f"/v1/rivalry/{original['group_id']}/continue"
    request_headers = headers(rivalry_domain, "Alice", "continue-at-boundary")
    issued = rivalry_ticket(rivalry_domain, original["group_id"])
    submit(rivalry_domain, issued, "Alice", frames=20)
    timestamp = original["ends_at"] - 1
    monkeypatch.setattr("bmt_backend.rivalry.now", lambda: timestamp)
    assert current(rivalry_domain)["state"] == "active"
    assert rivalry_domain.client.post(url, json={}, headers=request_headers).status_code == 409
    timestamp += 1
    assert current(rivalry_domain)["state"] == "settling"
    assert rivalry_domain.client.post(url, json={}, headers=request_headers).status_code == 409
    with rivalry_domain.factory() as session:
        assert not session.get(RivalryMember, (original["group_id"], rivalry_domain.players["Alice"])).acknowledged
    assert process_one(rivalry_domain.app)
    finale = current(rivalry_domain)
    assert finale["state"] == "complete" and finale["standings"][0]["points"] == 30
    assert rivalry_domain.client.post(url, json={}, headers=request_headers).status_code == 200
    next_week = join(rivalry_domain, key="join-next-week")
    assert next_week == join(rivalry_domain, key="join-next-week")
    assert next_week["state"] == "active" and next_week["group_id"] != original["group_id"]
    assert next_week["ends_at"] == original["ends_at"] + 7 * 86400
    assert len(next_week["tracks"]) == 5 and next_week["standings"][0]["points"] == 0
    assert rivalry_ticket(rivalry_domain, next_week["group_id"])["rivalry_group"] == next_week["group_id"]
    retained = rivalry_domain.client.get(f"/v1/rivalry/{original['group_id']}", headers=headers(rivalry_domain, "Alice")).json()
    assert retained["standings"] == finale["standings"] and retained["tracks"] == finale["tracks"]
