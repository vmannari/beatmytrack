"""Published-only, prepared-geometry catalogue and factual redacted player context."""

from uuid import uuid4

import pytest
from sqlalchemy import event, func, select
from test_studio import evidence, headers  # noqa: F401

from bmt_backend import studio_catalogue
from bmt_backend.commerce_models import Entitlements
from bmt_backend.identity_models import Player
from bmt_backend.quality_models import QualityFact
from bmt_backend.resume_models import ResumeWallet
from bmt_backend.studio_case_models import StudioCase, StudioCaseEvent
from bmt_backend.telemetry_models import ProductPlayerDay, ProductProfile, ProductState
from bmt_backend.track_models import Track, TrackVersion


@pytest.fixture
def catalogue(evidence, monkeypatch):  # noqa: F811
    client, app, ids = evidence
    # The owned fixture includes this router before root shell integration.
    app.include_router(studio_catalogue.router)
    monkeypatch.setattr(studio_catalogue, "now", lambda: 2000000000)
    with app.state.session_factory() as db:
        version = db.get(TrackVersion, ids["version"])
        version.discovery = {"theme": "storm", "points": [[0, 0], [20, 15], [40, 0], [0, 0]]}
        version.published_at = 120
        version.created_at = 100
        version.rating_sum, version.rating_count, version.verified_finishers = 18, 4, 77
        other = db.scalar(select(TrackVersion).where(TrackVersion.track_id == version.track_id,
            TrackVersion.id != version.id))
        other.published_at = 220
        other.created_at = 200
        other.discovery = {"theme": "winter", "points": [[-2, -2], [3, 3], [-2, -2]]}
        draft = TrackVersion(track_id=version.track_id, number=3, name="Private local draft",
            content_hash="f" * 64, manifest={}, state="draft", created_at=300)
        db.add(draft)
        track = Track(owner_id=ids["other"], official=True, hidden=True)
        db.add(track)
        db.flush()
        published = TrackVersion(track_id=track.id, number=1, name="A official track", content_hash="1" * 64,
            manifest={}, state="published", created_at=100, published_at=100,
            discovery={"theme": "storm", "points": [[0, 0], [10, 10]]},
            rating_sum=5, rating_count=1, verified_finishers=20)
        db.add(published)
        db.add(QualityFact(day=0, kind="discovery", dimension="d" * 64,
            context={"track_version_id": version.id}, reports=12, samples=3, slow=0))
        state = db.get(ProductState, 1)
        state.collection_started_at, state.processed_through = 1, 1000
        db.commit()
        ids.update(draft=draft.id, newer=other.id, official=published.id)
    return client, app, ids


def test_catalogue_auth_published_only_and_prepared_geometry(catalogue):
    client, app, ids = catalogue
    for path in ("tracks", "players", "tracks/" + ids["version"], "players/" + ids["player"]):
        assert client.get("/v1/admin/catalogue/" + path).status_code == 401
        response = client.get("/v1/admin/catalogue/" + path, headers=headers())
        assert response.status_code == 200, response.text
        assert response.headers["cache-control"] == "no-store"
    data = client.get("/v1/admin/catalogue/tracks?versions=all&since=0&until=86400", headers=headers()).json()
    assert data["total"] == 3
    assert ids["draft"] not in str(data) and "Private local draft" not in str(data)
    original = next(item for item in data["items"] if item["id"] == ids["version"])
    assert original["preview"]["points"] == [[0, 0], [20, 15], [40, 0], [0, 0]]
    assert original["preview"]["source"] == "stored_discovery_projection"
    assert original["discovery"] == {"exposures": 12, "selections": 3}
    newer = next(item for item in data["items"] if item["id"] == ids["newer"])
    assert newer["discovery"] is None  # Unobserved is not 0% finish.
    assert client.get("/v1/admin/catalogue/tracks/" + ids["draft"], headers=headers()).status_code == 404
    assert client.get("/v1/admin/catalogue/tracks/" + str(uuid4()), headers=headers()).status_code == 404
    assert client.get("/v1/admin/catalogue/tracks/not-a-uuid", headers=headers()).status_code == 422
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(Entitlements)) == 0
        assert db.scalar(select(func.count()).select_from(ResumeWallet)) == 0


def test_tracks_search_sort_filters_versions_and_paging_anchor(catalogue):
    client, app, ids = catalogue
    path = "/v1/admin/catalogue/tracks"
    get = lambda query: client.get(path + "?" + query, headers=headers()).json()
    assert get("versions=latest")["total"] == 2
    assert {r["id"] for r in get("versions=all&theme=storm")["items"]} == {ids["official"], ids["version"]}
    assert get("origin=official")["items"][0]["id"] == ids["official"]
    assert get("visibility=hidden")["items"][0]["id"] == ids["official"]
    assert get("visibility=visible")["total"] == 1
    assert get("versions=all&min_rating=4.6")["items"][0]["id"] == ids["official"]
    assert get("versions=all&min_finishers=50")["items"][0]["id"] == ids["version"]
    assert get("versions=all&sort=rating&direction=desc")["items"][0]["id"] == ids["official"]
    assert get("versions=all&sort=rating&direction=asc")["items"][-1]["rating_average"] is None
    assert get("q=Other+racer")["items"][0]["id"] == ids["official"]
    assert get("q=%25")["total"] == 0  # SQL LIKE metacharacters stay literal.
    assert get("creator_id=" + ids["player"])["total"] == 1
    first = get("versions=all&sort=name&direction=asc&limit=1&anchor=2000000000")
    with app.state.session_factory() as db:
        extra = Track(owner_id=ids["other"])
        db.add(extra)
        db.flush()
        db.add(TrackVersion(track_id=extra.id, number=1, name="AAA later insert", content_hash="2" * 64,
            manifest={}, state="published", created_at=2000000001, published_at=2000000001))
        db.commit()
    second = get("versions=all&sort=name&direction=asc&limit=1&offset=1&anchor=" + str(first["anchor"]))
    assert second["total"] == first["total"] == 3
    assert second["items"][0]["id"] != first["items"][0]["id"]
    for query in ("sort=raw-sql", "limit=101", "offset=10001", "min_rating=nan", "anchor=2000000001",
                  "creator_id=nope", "visibility=draft", "versions=drafts"):
        assert client.get(path + "?" + query, headers=headers()).status_code == 422, query


def test_shape_projection_is_bounded_and_bad_stored_points_are_unavailable():
    valid = studio_catalogue.preview({"theme": "pine", "points": [[n, n] for n in range(1000)]})
    assert len(valid["points"]) == 96 and valid["available"] is True
    for points in ([True, "secret"], [[True, 0], [0, False]], [[float("inf"), 0], [0, float("nan")]],
                   [[100001, 0]], {"payload": "untrusted"}):
        assert studio_catalogue.preview({"points": points})["available"] is False


def test_track_detail_redaction_and_source_pinned_timing(catalogue):
    client, app, ids = catalogue
    with app.state.session_factory() as db:
        version = db.get(TrackVersion, ids["version"])
        version.manifest = {"tick_rate": 240, "laps": 5, "access_token": "secret-manifest"}
        version.creator_test_run_id = ids["run"]
        case = StudioCase(track_id=version.track_id, title="Checkpoint review")
        db.add(case)
        db.commit()
    response = client.get("/v1/admin/catalogue/tracks/" + ids["version"], headers=headers())
    data = response.json()
    assert data["recent_races"][0]["accepted_seconds"] == 100
    assert data["track"]["creator_test_run_id"] == ids["run"]
    assert data["cases"][0]["title"] == "Checkpoint review"
    assert data["track"]["manifest"] == {"tick_rate": 240, "laps": 5}
    assert len(data["versions"]) == 2
    for secret in ("secret-manifest", "private-provider-subject", "private-worker-lease", "Private local draft"):
        assert secret not in response.text


def test_players_include_all_types_and_richer_authoritative_context(catalogue):
    client, app, ids = catalogue
    with app.state.session_factory() as db:
        db.get(Player, ids["other"]).is_test_driver = True
        case = StudioCase(player_id=ids["player"], title="Delayed resource investigation", created_at=600, updated_at=610)
        db.add(case)
        db.flush()
        db.add(StudioCaseEvent(id=str(uuid4()), case_id=case.id, actor="owner", kind="note", revision=0,
            detail={"text": "Evidence only"}, request_hash="c" * 64, created_at=610))
        db.add(ProductPlayerDay(day=50, player_id=ids["player"]))
        db.add(ProductProfile(player_id=ids["player"], first_activity_at=400,
            milestones=[["menu_ready", 400, "private-session", 0, 0]], projection={}, quality={}))
        db.commit()
    data = client.get("/v1/admin/catalogue/players", headers=headers()).json()
    assert data["total"] == 2 and data["summary"]["artificial"] == 1
    row = next(p for p in data["items"] if p["id"] == ids["player"])
    assert row["races"] == {"submissions": 1, "verified_submissions": 1, "last_submission_at": 200}
    assert row["providers"] == ["google"] and row["published_versions"] == 2
    assert row["open_cases"] == 1 and row["personal_bests"] == 1 and row["last_observed_activity_day"] == 50
    assert client.get("/v1/admin/catalogue/players?population=real", headers=headers()).json()["total"] == 1
    assert client.get("/v1/admin/catalogue/players?population=artificial", headers=headers()).json()["total"] == 1
    assert client.get("/v1/admin/catalogue/players?provider=google", headers=headers()).json()["total"] == 1
    detail = client.get("/v1/admin/catalogue/players/" + ids["player"], headers=headers())
    record = detail.json()
    assert record["support"]["effective"]["publishing_slots"] == 1
    assert record["activity"]["open_cases"] == 1
    assert record["case_activity"][0]["kind"] == "note"
    assert record["observed_journey"]["milestones"] == [{"name": "menu_ready", "at": 400}]
    assert record["coverage"]["verified_recovery"] == record["coverage"]["financial_revenue"] == "unavailable"
    for secret in ("private-provider-subject", "private-session", "Evidence only", "access_token", "refresh_token"):
        assert secret not in detail.text
    with app.state.session_factory() as db:
        assert db.scalar(select(func.count()).select_from(Entitlements)) == 0
        assert db.scalar(select(func.count()).select_from(ResumeWallet)) == 0


def test_published_reads_are_only_reads_and_invalid_filters_fail(catalogue):
    client, _app, ids = catalogue
    for path in ("tracks", "players", "tracks/" + ids["version"], "players/" + ids["player"]):
        assert client.post("/v1/admin/catalogue/" + path, headers=headers("owner"), json={}).status_code == 405
    for query in ("population=guests", "state=deleted", "limit=101", "offset=10001", "sort=spend"):
        assert client.get("/v1/admin/catalogue/players?" + query, headers=headers()).status_code == 422
    assert client.get("/v1/admin/catalogue/players/" + str(uuid4()), headers=headers()).status_code == 404


def test_track_list_queries_only_prepared_metadata_and_uses_sort_index(catalogue):
    client, app, ids = catalogue
    # Exercise a catalogue-sized table, with fresh planner statistics. Tiny
    # fixtures can correctly prefer a selective state index and an in-memory sort.
    with app.state.session_factory() as db:
        parent = db.get(TrackVersion, ids["version"]).track_id
        db.add_all(TrackVersion(track_id=parent, number=index + 4, name=f"Indexed catalogue {index:04}",
            content_hash="3" * 64, manifest={}, state="published", created_at=100,
            published_at=100) for index in range(2000))
        db.commit()
        db.connection().exec_driver_sql("ANALYZE")
        db.commit()
    statements = []

    def capture(_connection, _cursor, statement, parameters, _context, _many):
        if statement.lstrip().upper().startswith("SELECT"):
            statements.append((statement, parameters))

    event.listen(app.state.engine, "before_cursor_execute", capture)
    try:
        assert client.get("/v1/admin/catalogue/tracks?sort=name&direction=asc&versions=all",
            headers=headers()).status_code == 200
    finally:
        event.remove(app.state.engine, "before_cursor_execute", capture)
    assert not any("runs" in sql or "personal_bests" in sql or "product_events" in sql for sql, _params in statements)
    page_sql, page_params = next((sql, params) for sql, params in statements
        if "ORDER BY lower(track_versions.name)" in sql)
    with app.state.session_factory() as db:
        plans = db.connection().exec_driver_sql("EXPLAIN QUERY PLAN " + page_sql, page_params).all()
        assert any("ix_studio_published_name" in row[-1] for row in plans), plans
        assert not any("TEMP B-TREE" in row[-1] for row in plans), plans
