"""Executable v3 contracts: global coverage without catalogue vectors."""
import time
import uuid
from types import SimpleNamespace

import pytest
from sqlalchemy import event, func, select, update
from test_discovery_paging import auth_app as auth_app_fixture

from bmt_backend.discovery_models import (
    DiscoveryBoundary,
    DiscoveryEntry,
    DiscoverySession,
)
from bmt_backend.discovery_projection import settle_for_diagnostics
from bmt_backend.track_models import Track, TrackVersion

auth_app = auth_app_fixture


@pytest.fixture
def indexed(auth_app, auth_client, sign_in):
    login = sign_in("Indexed author")
    owner = login["player"]["id"]
    stamp = int(time.time()) - 10
    tracks = [{"id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"v3-track-{i}")), "owner_id": owner,
        "official": i < 9} for i in range(180)]
    versions = [{"id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"v3-version-{i}")), "track_id": t["id"],
        "number": 1, "name": f"Circuit {i:05d}", "content_hash": "a" * 64, "manifest": {},
        "discovery": {"theme": "pine" if i % 2 else "desert", "points": [[0,0],[10,0],[10,10]]},
        "state": "published", "published_at": stamp-i, "created_at": stamp-i, "verified_finishers": i % 100,
        "rating_sum": 0, "rating_count": 0} for i, t in enumerate(tracks)]
    with auth_app.state.session_factory() as db:
        db.execute(Track.__table__.insert(), tracks)
        db.execute(TrackVersion.__table__.insert(), versions)
        db.commit()
    settle_for_diagnostics(auth_app.state.session_factory)
    return SimpleNamespace(app=auth_app, client=auth_client, tracks=tracks, versions=versions,
        owner=owner, token=login["access_token"])


def browse(d, query=None, cursor="", **extra):
    body = {"cursor": cursor} if cursor else {"query": query or {}}
    response = d.client.post("/v1/discovery/v3/tracks", json={**body, **extra})
    assert response.status_code == 200, response.text
    return response.json()


def test_complete_bounded_pages_and_revisit(indexed):
    d = indexed
    page = browse(d, {"sort": "name"})
    assert page["total"] is None and len(page["items"]) == 20
    first = page
    ids = []
    while True:
        ids.extend(i["track_id"] for i in page["items"])
        if not page["next_cursor"]:
            break
        second = browse(d, cursor=page["next_cursor"])
        assert second["previous_cursor"] == page["page_cursor"]
        page = second
    assert len(ids) == len(set(ids)) == 180
    assert browse(d, cursor=first["page_cursor"])["items"] == first["items"]
    with d.app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(DiscoveryEntry)) == 180
        assert db.scalar(select(func.count()).select_from(DiscoveryBoundary)) == 9
        assert not any("version_ids" in c.name for c in DiscoverySession.__table__.columns)


def test_freezes_rank_filters_and_version_while_hides_remain_current(indexed):
    d = indexed
    first = browse(d, {"sort": "score"})
    with d.app.state.session_factory() as db:
        db.execute(update(TrackVersion).where(TrackVersion.id == d.versions[45]["id"])
            .values(rating_sum=500, rating_count=100))
        db.add(TrackVersion(id=str(uuid.uuid4()), track_id=d.tracks[0]["id"], number=2, name="New revision",
            content_hash="b"*64, manifest={}, discovery={"theme":"pine","points":[]},
            state="published", published_at=int(time.time()), rating_sum=0, rating_count=0))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=int(time.time())+61)
    assert [i["version_id"] for i in browse(d, cursor=first["page_cursor"])["items"]] == [i["version_id"] for i in first["items"]]
    fresh = browse(d, {"sort":"score"})
    assert fresh["items"][0]["track_id"] == d.tracks[45]["id"]
    hidden = first["items"][0]["track_id"]
    with d.app.state.session_factory() as db:
        db.execute(update(Track).where(Track.id == hidden).values(hidden=True))
        db.commit()
    assert hidden not in [i["track_id"] for i in browse(d, cursor=first["page_cursor"])["items"]]


def test_personal_filters_and_anchor(indexed):
    d = indexed
    favorite = d.tracks[-1]["id"]
    one = browse(d, {"section":"favorites","ids":[favorite]})
    assert [i["track_id"] for i in one["items"]] == [favorite] and not one["has_more"]
    assert not browse(d, {"section":"favorites","ids":[]})["items"]
    assert [i["track_id"] for i in browse(d, {"race_history":"raced","raced_ids":[favorite]})["items"]] == [favorite]
    assert all(i["track_id"] != favorite for i in browse(d, {"race_history":"unraced","raced_ids":[favorite]})["items"])
    anchored = browse(d, {"sort":"name"}, locate_version=d.versions[143]["id"])
    assert anchored["anchored"] and anchored["items"][0]["version_id"] == d.versions[143]["id"]


def test_recommended_mix_and_no_duplicates(indexed):
    d = indexed
    page = browse(d)
    first = [i["track_id"] for i in page["items"][:4]]
    assert first[:3] == [t["id"] for t in d.tracks[:3]] and first[3] == d.tracks[9]["id"]
    found = []
    while True:
        found.extend(i["track_id"] for i in page["items"])
        if not page["next_cursor"]:
            break
        page = browse(d, cursor=page["next_cursor"])
    assert len(found) == len(set(found)) == 180


def test_sparse_random_and_retired_endpoint(indexed):
    d = indexed
    first = browse(d)
    survivor = d.tracks[-1]["id"]
    with d.app.state.session_factory() as db:
        db.execute(update(Track).where(Track.id != survivor).values(hidden=True))
        db.commit()
    result = d.client.post("/v1/discovery/v3/random", json={"cursor": first["page_cursor"], "exclude":survivor})
    assert result.status_code == 200, result.text
    assert result.json()["items"][0]["track_id"] == survivor
    assert d.client.post("/v1/discovery/tracks", json={}).status_code == 426


def test_cursor_tamper_scope_and_page_query_cost(indexed):
    d = indexed
    first = browse(d, {"sort":"new"})
    headers = {"Authorization":"Bearer " + d.token}
    denied = d.client.post("/v1/discovery/v3/tracks", json={"cursor":first["page_cursor"]},headers=headers)
    assert denied.status_code == 422
    assert d.client.post("/v1/discovery/v3/tracks", json={"cursor": "bad"}).status_code == 422
    statements = []
    def capture(_connection, _cursor, sql, *_):
        statements.append(sql)
    event.listen(d.app.state.engine, "before_cursor_execute", capture)
    try:
        browse(d, cursor=first["next_cursor"])
    finally:
        event.remove(d.app.state.engine, "before_cursor_execute", capture)
    assert not any("FROM runs" in s or "discovery_snapshots" in s or "count(" in s.lower() for s in statements)
    assert sum("discovery_entries" in s and "SELECT" in s.upper() for s in statements) == 1


def test_random_slot_sampling_reaches_any_track_and_exhaustion_is_retryable(indexed, monkeypatch):
    from bmt_backend import discovery_v3
    from bmt_backend.discovery_models import DiscoveryHead, DiscoveryPartition
    d = indexed
    first = browse(d)
    with d.app.state.session_factory() as db:
        target = db.get(DiscoveryHead, d.tracks[-1]["id"])
        sizes = [p.slots for p in db.scalars(select(DiscoveryPartition).order_by(DiscoveryPartition.id))]
        draw = sum(sizes[:target.partition]) + target.slot - 1
    monkeypatch.setattr(discovery_v3, "RANDOM_SMALL", 0)
    monkeypatch.setattr(discovery_v3.secrets, "randbelow", lambda _maximum: draw)
    response = d.client.post("/v1/discovery/v3/random", json={"cursor":first["page_cursor"]})
    assert response.status_code == 200, response.text
    assert response.json()["items"][0]["track_id"] == d.tracks[-1]["id"]
    monkeypatch.setattr(discovery_v3, "RANDOM_TRIALS", 0)
    response = d.client.post("/v1/discovery/v3/random", json={"cursor":first["page_cursor"]})
    assert response.status_code == 503 and response.json()["detail"] == "DISCOVERY_RANDOM_BUDGET"
    assert "items" not in response.json() and response.headers["retry-after"] == "2"


def test_expiry_and_query_budget_never_become_false_empty_results(indexed, monkeypatch):
    from bmt_backend import discovery_v3
    d = indexed
    first = browse(d)
    monkeypatch.setattr(discovery_v3, "QUERY_SECONDS", 0)
    response = d.client.post("/v1/discovery/v3/tracks", json={"cursor":first["page_cursor"]})
    assert response.status_code == 503 and response.json()["detail"] == "DISCOVERY_QUERY_BUDGET"
    monkeypatch.setattr(discovery_v3, "QUERY_SECONDS", 1.5)
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoverySession).values(expires_at=int(time.time())-1))
        db.commit()
    assert d.client.post("/v1/discovery/v3/tracks", json={"cursor":first["page_cursor"]}).status_code == 410
    fresh = browse(d)
    assert len(fresh["items"]) == 20 and fresh["page_cursor"] != first["page_cursor"]


def test_filters_are_snapshot_based_and_source_rating_sum_supports_500m_votes(indexed):
    d = indexed
    frozen = browse(d, {"feed":"rated", "minimum_rating":4})
    assert frozen["items"] == []
    with d.app.state.session_factory() as db:
        db.execute(update(TrackVersion).where(TrackVersion.id == d.versions[0]["id"])
            .values(rating_sum=2500000000, rating_count=500000000))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=int(time.time())+61)
    assert browse(d, cursor=frozen["page_cursor"])["items"] == []
    fresh = browse(d, {"feed":"rated", "minimum_rating":4})
    assert fresh["items"][0]["rating_count"] == 500000000
    with d.app.state.session_factory() as db:
        score = db.scalar(select(DiscoveryEntry.score).where(DiscoveryEntry.track_id == d.tracks[0]["id"],
            DiscoveryEntry.until.is_(None)))
        assert 4*10**18 < score <= 5*10**18


def test_rated_and_unrated_keyset_ties_cover_all_tracks(indexed):
    d = indexed
    with d.app.state.session_factory() as db:
        db.execute(update(TrackVersion).where(TrackVersion.id.in_([v["id"] for v in d.versions[:45]]))
            .values(rating_sum=40, rating_count=10))
        db.commit()
    settle_for_diagnostics(d.app.state.session_factory, clock=int(time.time())+61)
    page = browse(d, {"sort":"score"})
    found = []
    while True:
        found.extend(item["track_id"] for item in page["items"])
        if not page["next_cursor"]:
            break
        page = browse(d, cursor=page["next_cursor"])
    assert len(found) == len(set(found)) == 180
    assert set(found[:45]) == {t["id"] for t in d.tracks[:45]}


def test_stale_worker_and_pending_source_lag_reject_new_views(indexed):
    from bmt_backend.discovery_models import DiscoveryChange, DiscoveryPartition
    d = indexed
    first = browse(d)
    stamp = int(time.time())
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoveryPartition).where(DiscoveryPartition.id == 0).values(checked_at=0))
        db.commit()
    response = d.client.post("/v1/discovery/v3/tracks",json={"query":{"search":"fresh"}})
    assert response.status_code == 503 and response.json()["detail"] == "DISCOVERY_INDEX_STALE"
    # Frozen sessions remain readable under current authoritative visibility.
    assert len(browse(d,cursor=first["page_cursor"])["items"]) == 20
    with d.app.state.session_factory() as db:
        db.execute(update(DiscoveryPartition).values(checked_at=time.time_ns()))
        db.add(DiscoveryChange(partition=0,kind="stats",target=d.tracks[0]["id"],
            created_at=stamp-121,finished_at=0))
        db.commit()
    response = d.client.post("/v1/discovery/v3/tracks",json={"query":{"search":"fresh"}})
    assert response.status_code == 503 and response.json()["detail"] == "DISCOVERY_INDEX_STALE"


@pytest.mark.parametrize("field,value",[("offset",0),("cursor","old"),("locate_version","old"),("exclude","old")])
def test_legacy_paging_fields_are_rejected_in_v3_query(auth_client,field,value):
    response = auth_client.post("/v1/discovery/v3/tracks",json={"query":{field:value}})
    assert response.status_code == 422


def test_personal_identifier_lengths_are_validated_before_storage(auth_client):
    for field in ("ids","raced_ids"):
        response = auth_client.post("/v1/discovery/v3/tracks",json={"query":{field:["x"*81]}})
        assert response.status_code == 422


@pytest.mark.parametrize("query",[{"sort":"name"},{"sort":"score"},{}])
def test_visibility_removals_do_not_refill_across_visited_page_boundaries(indexed,query):
    d = indexed
    first = browse(d,query)
    second = browse(d,cursor=first["next_cursor"])
    hidden = first["items"][0]["track_id"]
    with d.app.state.session_factory() as db:
        db.get(Track,hidden).hidden = True
        db.commit()
    reloaded = browse(d,cursor=first["page_cursor"])
    assert len(reloaded["items"]) == 19
    assert reloaded["next_cursor"] == first["next_cursor"]
    assert [i["track_id"] for i in reloaded["items"]] == [i["track_id"] for i in first["items"] if i["track_id"] != hidden]
    assert not ({i["track_id"] for i in reloaded["items"]} & {i["track_id"] for i in second["items"]})
    with d.app.state.session_factory() as db:
        db.get(Track,hidden).hidden = False
        db.commit()
    assert browse(d,cursor=first["page_cursor"])["items"] == first["items"]


def test_new_view_after_unblock_does_not_reuse_a_blocked_empty_view(indexed,sign_in):
    from sqlalchemy import delete

    from bmt_backend.community_models import PlayerBlock
    d = indexed
    viewer = sign_in("Block viewer")
    headers = {"Authorization":"Bearer "+viewer["access_token"]}
    with d.app.state.session_factory() as db:
        db.add(PlayerBlock(player_id=viewer["player"]["id"],blocked_id=d.owner))
        db.commit()
    first = d.client.post("/v1/discovery/v3/tracks",headers=headers,json={"query":{}})
    assert first.status_code == 200,first.text
    assert first.json()["items"] == [] and not first.json()["has_more"]
    with d.app.state.session_factory() as db:
        db.execute(delete(PlayerBlock).where(PlayerBlock.player_id == viewer["player"]["id"]))
        db.commit()
    second = d.client.post("/v1/discovery/v3/tracks",headers=headers,json={"query":{}})
    assert second.status_code == 200,second.text
    assert len(second.json()["items"]) == 20 and second.json()["page_cursor"] != first.json()["page_cursor"]
