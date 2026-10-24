"""Useful Studio evidence remains exact while directory and tab work is bounded."""
# ruff: noqa: F811 - imported pytest fixtures are dependencies by name
from contextlib import contextmanager
from uuid import uuid4

import pytest
from sqlalchemy import event, inspect
from test_studio import evidence  # noqa: F401
from test_studio_catalogue import catalogue  # noqa: F401
from test_studio_platform import ANALYST, DAY, OWNER, platform  # noqa: F401

from bmt_backend.cursors import decode_cursor, encode_cursor
from bmt_backend.identity_models import Player
from bmt_backend.studio_platform_models import AnalysisDay, AnalysisPerson, AnalysisSession, AnalysisState
from bmt_backend.track_models import now


@contextmanager
def statements(app):
    queries = []

    class SQL(str):
        pass

    def capture(_connection, _cursor, statement, _parameters, context, _executemany):
        # Exclude fixed HTTP rate-budget writes and the indexed bearer probe.
        # These assertions measure report SQL, including its read transaction.
        if "rate_buckets" in statement or "WHERE session_tokens.access_hash" in statement:
            return
        query = SQL(statement)
        compiled = getattr(context, "compiled", None)
        query.offset = getattr(getattr(compiled, "statement", None), "_offset_clause", None)
        queries.append(query)

    event.listen(app.state.engine, "before_cursor_execute", capture)
    try:
        yield queries
    finally:
        event.remove(app.state.engine, "before_cursor_execute", capture)


def test_overview_has_no_lifetime_account_content_or_history_scan(platform):
    app, client, _player, _auth = platform
    with statements(app) as sql:
        response = client.get("/v1/admin/overview?days=90", headers=ANALYST)
    assert response.status_code == 200
    data = response.json()
    assert data["pulse_until"] - data["pulse_since"] == 300
    assert not {"players", "disabled", "tracks", "versions", "racers", "daily"} & data.keys()
    assert len(sql) == 2 and not any("FROM players" in query or "track_versions" in query for query in sql)
    assert "runs.finished_at >=" in sql[0] and "runs.finished_at <=" in sql[0]


@pytest.mark.parametrize("kind", ["players", "tracks"])
def test_catalogue_uses_lookahead_and_never_counts_population_or_player_history(catalogue, kind):
    client, app, _ids = catalogue
    with statements(app) as sql:
        response = client.get(f"/v1/admin/catalogue/{kind}?limit=1", headers=ANALYST)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["total"] is None and data["next_cursor"] and len(data["items"]) == 1
    assert not any("count(" in query.lower() for query in sql)
    if kind == "players":
        assert len(sql) == 3, sql  # read transaction, one player page, one provider batch
        assert not any(name in query for name in ("FROM runs", "personal_bests", "studio_cases", "product_player_days") for query in sql)
        assert data["summary_scope"] == "page" and "races" not in data["items"][0]


@pytest.mark.parametrize("sort", ["created", "name"])
@pytest.mark.parametrize("direction", ["asc", "desc"])
def test_player_cursor_forward_backward_ties_filter_fence_and_later_inserts(platform, sort, direction):
    app, client, _player, _auth = platform
    stamp = now() - 100
    with app.state.session_factory() as db:
        rows = [Player(id=str(uuid4()), display_name=f"Page fixture {i:03}", created_at=stamp,
                       is_test_driver=i % 2 == 0) for i in range(9)]
        db.add_all(rows)
        db.commit()
        expected = [p.id for p in sorted(rows, key=lambda p: (p.created_at if sort == "created" else p.display_name.lower(), p.id),
                                        reverse=direction == "desc")]
    params = {"q": "Page fixture", "sort": sort, "direction": direction, "limit": 3, "anchor": now()}
    url = "/v1/admin/catalogue/players"
    first = client.get(url, params=params, headers=OWNER).json()
    with app.state.session_factory() as db:
        db.add(Player(display_name="Page fixture later", created_at=params["anchor"] + 1))
        db.commit()
    with statements(app) as sql:
        second = client.get(url, params={**params, "cursor": first["next_cursor"]}, headers=OWNER).json()
        third = client.get(url, params={**params, "cursor": second["next_cursor"]}, headers=OWNER).json()
        previous = client.get(url, params={**params, "cursor": third["previous_cursor"]}, headers=OWNER).json()
    assert [p["id"] for page in (first, second, third) for p in page["items"]] == expected
    assert previous["items"] == second["items"] and not third["has_more"]
    assert all(query.offset is None for query in sql) and not any("count(" in query.lower() for query in sql)
    assert client.get(url, params={**params, "state": "disabled", "cursor": first["next_cursor"]}, headers=OWNER).status_code == 422
    invalid = decode_cursor(first["next_cursor"])
    invalid["value"] = True
    assert client.get(url, params={**params, "cursor": encode_cursor(invalid)}, headers=OWNER).status_code == 422


@pytest.mark.parametrize("sort", ["published", "name", "creator", "rating", "finishers"])
@pytest.mark.parametrize("direction", ["asc", "desc"])
def test_track_cursor_matches_full_sort_including_unrated_and_backwards(catalogue, sort, direction):
    client, _app, _ids = catalogue
    url = "/v1/admin/catalogue/tracks"
    params = {"versions": "all", "sort": sort, "direction": direction, "anchor": 2000000000}
    expected = client.get(url, params=params, headers=ANALYST).json()["items"]
    pages, cursor = [], None
    for _ in range(3):
        data = client.get(url, params={**params, "limit": 1, **({"cursor": cursor} if cursor else {})}, headers=ANALYST).json()
        pages.append(data)
        cursor = data["next_cursor"]
    assert [r for data in pages for r in data["items"]] == expected and cursor is None
    previous = client.get(url, params={**params, "limit": 1, "cursor": pages[-1]["previous_cursor"]}, headers=ANALYST).json()
    assert previous["items"] == pages[-2]["items"]


def test_exact_player_identifier_uses_equality_not_text_scan(platform):
    app, client, player, _auth = platform
    for path in ("catalogue/players", "entities/players"):
        with statements(app) as sql:
            data = client.get("/v1/admin/" + path, params={"q": player}, headers=OWNER).json()
        assert [row["id"] for row in data["items"]] == [player]
        assert not any("LIKE" in query for query in sql)


def test_full_length_unicode_names_have_valid_bounded_cursors(platform):
    app, client, _player, _auth = platform
    prefix = "\U0001f3ce" * 39
    with app.state.session_factory() as db:
        db.add_all([Player(display_name=prefix + str(i), created_at=now() - 10) for i in range(3)])
        db.commit()
    params = {"q": prefix, "sort": "name", "direction": "asc", "limit": 1, "anchor": now()}
    url = "/v1/admin/catalogue/players"
    first = client.get(url, params=params, headers=OWNER).json()
    assert len(first["next_cursor"]) <= 2048
    response = client.get(url, params={**params, "cursor": first["next_cursor"]}, headers=OWNER)
    assert response.status_code == 200, response.text
    assert response.json()["items"][0]["display_name"] == prefix + "1"


def test_finance_keeps_period_flows_without_global_wallet_or_unused_purchase_counts(platform):
    app, client, _p, _a = platform
    with statements(app) as sql:
        response = client.get("/v1/admin/finance", headers=OWNER)
    assert response.status_code == 200
    assert "money" in response.json() and "coins" in response.json() and "wallets" not in response.json()
    assert not any("coin_wallets" in query or "FROM purchases" in query for query in sql)
    assert "ix_studio_finance_received" in {index["name"] for index in inspect(app.state.engine).get_indexes("studio_finance_events")}


@pytest.fixture
def observations(platform):
    app, client, _p, _a = platform
    start = (now() // DAY - 45) * DAY
    with app.state.session_factory() as db:
        state = db.get(AnalysisState, 1)
        state.started_at, state.processed_through, state.latest_client_at = start, now(), now()
        for i in range(3):
            identity = str(uuid4())
            db.add(AnalysisPerson(player_id=identity, first_at=start + 100, first_build="report-fixture", first_platform="android",
                journey={"anchor": start + 100, "steps": i + 1, "truncated": False}))
            db.add(AnalysisSession(player_id=identity, session_id=str(uuid4()), first_at=start + 100, last_at=start + 200,
                foreground_ms=(i + 1) * 1000, build_id="report-fixture", platform="android"))
            for day in (0, 1, 7, 30):
                for dimension in ("one", "two"):
                    db.add(AnalysisDay(day=start // DAY + day, player_id=identity, dimension=dimension, build_id="report-fixture",
                        platform="android", mode="free_race", first_at=start + day * DAY, last_at=start + day * DAY,
                        counters={"active": 1, "race_started": i + 1, "race_finished": 1, "race_accepted": 1, "foreground_ms": 1000}))
        db.commit()
    return app, client, {"since": start, "until": start + DAY, "build_id": "report-fixture"}


@pytest.mark.parametrize("view", ["activity", "retention", "journey", "engagement"])
def test_behaviour_tabs_match_combined_exact_report_without_other_analyses(observations, view, record_property):
    app, client, params = observations
    url = "/v1/admin/analysis/behaviour"
    combined = client.get(url, params={**params, "view": "all"}, headers=ANALYST).json()
    with statements(app) as sql:
        response = client.get(url, params={**params, "view": view}, headers=ANALYST)
    assert response.status_code == 200, response.text
    data = response.json()
    fields = {"activity": ("active_players", "counters", "daily"), "retention": ("retention",),
              "journey": ("first_race",), "engagement": ("engagement",)}[view]
    assert all(data[field] == combined[field] for field in fields)
    if view == "activity":
        assert data["active_players"] == 3 and data["counters"]["race_started"] == 12
        assert not any("studio_analysis_people" in query or "studio_analysis_sessions" in query for query in sql)
    if view == "retention":
        assert all(data["retention"][0]["d" + str(n)]["returned"] == 3 for n in (1, 7, 30))
        assert not any("studio_analysis_sessions" in query for query in sql)
    if view == "journey":
        assert data["first_race"]["eligible"] == 3 and [r["players"] for r in data["first_race"]["steps"]][:3] == [3, 2, 1]
        assert sum("FROM studio_analysis_people" in query for query in sql) == 1
    if view == "engagement":
        assert data["engagement"]["foreground_ms"] == 6000 and data["engagement"]["sessions"] == 3
    assert len(sql) <= 6
    record_property("report_sql_statements", len(sql))
