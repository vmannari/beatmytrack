"""Reuse preserves current authority and avoids repeated presentation work."""
import pytest
from sqlalchemy import event
from test_discovery_v3 import indexed as _indexed_fixture
from test_domains import domain as _domain_fixture
from test_domains import headers, submit
from test_rivalry import join, rivalry_ticket, seed

from bmt_backend import rivalry
from bmt_backend.community_models import PlayerBlock
from bmt_backend.identity_models import Player
from bmt_backend.rivalry_models import RivalryGroup, RivalryMember
from bmt_backend.track_models import Run, RunTicket, Track, TrackVersion
from bmt_backend.worker import process_one

reuse_domain = _domain_fixture
reuse_indexed = _indexed_fixture


def test_reusable_previews_keep_fresh_cards_and_validate_hints(reuse_indexed):
    d = reuse_indexed
    body = {"query": {"sort": "name"}, "preview_cache": True, "known_previews": []}
    first = d.client.post("/v1/discovery/v3/tracks", json=body)
    assert first.status_code == 200, first.text
    cold = first.json()
    assert cold["items"] and all("points" in row and "preview_hash" in row for row in cold["items"])
    with d.app.state.session_factory() as session:
        version = session.get(TrackVersion, cold["items"][0]["version_id"])
        version.rating_count += 1
        session.commit()
    request = {"cursor": cold["page_cursor"], "preview_cache": True,
               "known_previews": list({row["preview_hash"] for row in cold["items"]})}
    second = d.client.post("/v1/discovery/v3/tracks", json=request)
    assert second.status_code == 200, second.text
    warm = second.json()
    assert all("points" not in row for row in warm["items"])
    assert warm["items"][0]["rating_count"] == cold["items"][0]["rating_count"] + 1
    request["known_previews"] = []
    fallback = d.client.post("/v1/discovery/v3/tracks", json=request)
    assert fallback.status_code == 200 and all("points" in row for row in fallback.json()["items"])
    request["known_previews"] = ["a" * 64] * 33
    assert d.client.post("/v1/discovery/v3/tracks", json=request).status_code == 422


def enrolled(d):
    seed(d, 6)
    group = join(d, "Alice")["group_id"]
    join(d, "Bob")
    return group, f"/v1/rivalry/{group}"


def test_unchanged_snapshot_does_not_rebuild_and_uses_bounded_reads(reuse_domain, monkeypatch):
    d = reuse_domain
    _group, path = enrolled(d)
    group_path = path
    path = "/v1/rivalry/current?vehicle_id=compact"
    first = d.client.get(path, headers=headers(d, "Alice"))
    assert first.status_code == 200
    queries = []
    def record(*args):
        queries.append(args[2])
    def rebuilding(*args, **kwargs):
        raise AssertionError("Unchanged snapshot rebuilt standings")
    original = rivalry.standings_data
    monkeypatch.setattr(rivalry, "standings_data", rebuilding)
    event.listen(d.app.state.engine, "before_cursor_execute", record)
    try:
        same = d.client.get(path, headers={**headers(d, "Alice"), "If-None-Match": first.headers["etag"]})
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", record)
    assert same.status_code == 304 and same.content == b""
    reads = [query for query in queries if query.lstrip().upper().startswith("SELECT")]
    assert len(reads) <= 8, len(reads)
    assert "must-revalidate" in same.headers["cache-control"]
    monkeypatch.setattr(rivalry, "standings_data", original)
    assert d.client.get(group_path, headers=headers(d, "Carol")).status_code == 404
    assert d.client.get(group_path, headers={**headers(d, "Bob"), "If-None-Match": first.headers["etag"]}).status_code == 200


@pytest.mark.parametrize("change", ["name", "country", "appearance", "block", "hidden", "disabled", "redacted", "archive", "member"])
def test_mutable_snapshot_inputs_invalidate_cached_bytes(reuse_domain, change):
    d = reuse_domain
    group_id, path = enrolled(d)
    first = d.client.get(path, headers=headers(d, "Alice"))
    assert first.status_code == 200
    with d.factory() as session:
        group = session.get(RivalryGroup, group_id)
        bob = session.get(Player, d.players["Bob"])
        if change == "name":
            bob.display_name = "Changed rival"
        elif change == "country":
            bob.country_code = "FI"
        elif change == "appearance":
            bob.vehicle_appearances = {"compact": {"fixture": "changed"}}
        elif change == "block":
            session.add(PlayerBlock(player_id=d.players["Alice"], blocked_id=bob.id))
        elif change in ("hidden", "disabled", "redacted"):
            version = session.get(TrackVersion, group.tracks[0]["version_id"])
            track = session.get(Track, version.track_id)
            owner = session.get(Player, track.owner_id)
            if change == "hidden":
                track.hidden = True
            elif change == "disabled":
                owner.disabled = True
            else:
                owner.deleted_at = 123
                version.content_hash = "a" * 64
                version.redacted_track_hash = "b" * 64
        elif change == "archive":
            group.archived = True
        elif change == "member":
            session.delete(session.get(RivalryMember, (group_id, bob.id)))
        session.commit()
    changed = d.client.get(path, headers={**headers(d, "Alice"), "If-None-Match": first.headers["etag"]})
    assert changed.status_code == 200, (change, changed.text)
    assert changed.headers["etag"] != first.headers["etag"]
    value = changed.json()
    if change in ("hidden", "disabled", "archive"):
        assert not value["tracks"][0]["available"]
    if change == "redacted":
        entry = value["tracks"][0]["entry"]
        assert entry["creator"] == "Removed account" and entry["content_hash"] == "a" * 64
    if change == "block":
        assert next(row for row in value["standings"] if row["id"] == d.players["Bob"])["name"] == "Blocked player"


def test_week_boundary_pending_and_finished_personal_bests_invalidate(reuse_domain, monkeypatch):
    d = reuse_domain
    group_id, path = enrolled(d)
    stamp = 1900000000
    monkeypatch.setattr(rivalry, "now", lambda: stamp)
    with d.factory() as session:
        session.get(RivalryGroup, group_id).ends_at = stamp + 1
        session.commit()
    first = d.client.get(path, headers=headers(d, "Alice"))
    assert first.json()["state"] == "active"
    monkeypatch.setattr(rivalry, "now", lambda: stamp + 2)
    complete = d.client.get(path, headers={**headers(d, "Alice"), "If-None-Match": first.headers["etag"]})
    assert complete.status_code == 200 and complete.json()["state"] == "complete"
    # The clock changes without changing a row. Complete snapshots must not stay active.
    with d.factory() as session:
        group = session.get(RivalryGroup, group_id)
        from bmt_backend.rivalry_models import RivalryTicket
        from bmt_backend.runs import board_manifest
        from bmt_backend.track_models import Board
        board_id = group.tracks[0]["board_id"]
        if session.get(Board, board_id) is None:
            version = session.get(TrackVersion, group.tracks[0]["version_id"])
            session.add(Board(id=board_id, version_id=version.id, vehicle_id="compact", manifest=board_manifest(version, "compact")))
        session.flush()
        ticket = RunTicket(player_id=d.players["Alice"], board_id=board_id, expires_at=stamp+100)
        session.add(ticket); session.flush()
        session.add(RivalryTicket(ticket_id=ticket.id, group_id=group_id, slot=0, outcome={"personal_best": True}))
        run = Run(ticket_id=ticket.id, player_id=d.players["Alice"], board_id=board_id, replay_hash="a"*64,
                  status="queued", time_ticks=100, finished_at=stamp)
        session.add(run); session.commit(); run_id = run.id
    settling = d.client.get(path, headers={**headers(d, "Alice"), "If-None-Match": complete.headers["etag"]})
    assert settling.status_code == 200 and settling.json()["state"] == "settling"
    with d.factory() as session:
        session.get(Run, run_id).status = "verified"
        session.commit()
    final = d.client.get(path, headers={**headers(d, "Alice"), "If-None-Match": settling.headers["etag"]})
    assert final.status_code == 200 and final.json()["state"] == "complete"
    assert final.json()["personal_best_slots"] == [0]


def test_accepted_scores_replace_a_cached_standings_snapshot(reuse_domain):
    d = reuse_domain
    group, path = enrolled(d)
    first = d.client.get(path, headers=headers(d, "Alice"))
    ticket = rivalry_ticket(d, group, "Bob")
    submit(d, ticket, "Bob", 30)
    assert process_one(d.app)
    changed = d.client.get(path, headers={**headers(d, "Alice"), "If-None-Match": first.headers["etag"]})
    assert changed.status_code == 200
    bob = next(row for row in changed.json()["standings"] if row["id"] == d.players["Bob"])
    assert bob["completed"] == 1 and bob["points"] == 30


def test_completion_returns_one_wallet_for_a_batch_and_preserves_ownership(reuse_domain):
    from test_challenges import normal_run, setup
    d = reuse_domain
    version = setup(d)
    run_id = normal_run(d, version)
    path = "/v1/runs/" + run_id
    ordinary = d.client.get(path, headers=headers(d, "Alice"))
    assert "completion" not in ordinary.json()
    enriched = d.client.get(path + "?completion=true", headers=headers(d, "Alice")).json()
    assert enriched["completion"]["version"] == 1
    assert enriched["completion"]["reward"]["status"] == "credited"
    assert enriched["completion"]["wallet"]["balance"] >= enriched["completion"]["reward"]["amount"]
    batch = d.client.get("/v1/runs/status", params={"ids": run_id, "completion": "true"}, headers=headers(d, "Alice")).json()
    assert "completion_wallet" in batch and "wallet" not in batch["items"][0]["completion"]
    other = d.client.get(path + "?completion=true", headers=headers(d, "Bob"))
    assert other.status_code == 404
    ticket_id = enriched["ticket_id"]
    recovery = d.client.get(f"/v1/run-tickets/{ticket_id}/submission?completion=true", headers=headers(d, "Alice"))
    assert recovery.json()["run"]["completion"]["reward"] == enriched["completion"]["reward"]
