from test_daily_standings import auth, auth_app, feature, finish  # noqa: F401
from test_daily_standings import daily as daily_fixture

from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import digest

daily = daily_fixture


def prepare(d, monkeypatch):
    feature(d)
    bid = digest({"version_id": d.version.id, **board_manifest(d.version, "compact"), "comparison_population": "all"})
    times = {d.identities[name]["player"]["id"]: ticks
             for name, ticks in (("Alice", 2400), ("Bob", 1200), ("Carol", 3600), ("Creator", 6000))}
    laps = HistogramPopulation.from_rows(times.items(), {"board_id": bid})
    races = HistogramPopulation.from_rows([])
    monkeypatch.setattr("bmt_backend.histogram_snapshots.load_snapshot", lambda *args: ("first", {}, (races, laps)))
    return {"day": d.day, "version_id": d.version.id, "vehicle_id": "compact"}


def test_flying_lap_pages_and_nearby_candidate_do_not_write_scores(daily, monkeypatch):
    d = daily
    params = prepare(d, monkeypatch)
    page = d.client.get("/v1/track-of-the-day/lap-standings", params={**params, "limit": 2}, headers=auth(d))
    assert page.status_code == 200, page.text
    data = page.json()
    assert [row["display_name"] for row in data["items"]] == ["Bob", "Alice"]
    assert [row["time_ticks"] for row in data["items"]] == [1200, 2400]
    assert data["player"]["display_name"] == "Alice" and data["player"]["rank"] == 2
    next_page = d.client.get("/v1/track-of-the-day/lap-standings",
        params={**params, "limit": 2, "cursor": data["next_cursor"]}, headers=auth(d)).json()
    assert [row["display_name"] for row in next_page["items"]] == ["Carol", "Creator"]
    assert next_page["next_cursor"] is None
    nearby = d.client.get("/v1/track-of-the-day/lap-standings",
        params={**params, "around": True, "lap_ticks": 1800, "limit": 3}, headers=auth(d)).json()
    assert [row["display_name"] for row in nearby["items"]] == ["Bob", "Carol"]
    assert nearby["comparison"] == {"position": 2, "population": 4, "top_percent": 50, "candidate_ticks": 1800}
    assert nearby["player"]["time_ticks"] == 2400  # A candidate is only a comparison marker.
    slower = d.client.get("/v1/track-of-the-day/lap-standings",
        params={**params, "around": True, "lap_ticks": 5000, "limit": 3}, headers=auth(d)).json()
    assert [row["rank"] for row in slower["items"]] == [2, 4]
    assert slower["comparison"]["position"] == 3
    public = d.client.get("/v1/track-of-the-day/lap-standings", params=params).json()
    assert public["player"] is None and public["population"] == 4


def test_lap_page_scope_and_snapshot_cursors(daily, monkeypatch):
    d = daily
    params = prepare(d, monkeypatch)
    first = d.client.get("/v1/track-of-the-day/lap-standings", params={**params, "limit": 2}).json()
    assert d.client.get("/v1/track-of-the-day/lap-standings", params={**params, "day": d.day-1}).status_code == 409
    assert d.client.get("/v1/track-of-the-day/lap-standings", params={**params, "vehicle_id": "unknown"}).status_code == 422
    assert d.client.get("/v1/track-of-the-day/lap-standings", params={**params, "lap_ticks": 0}).status_code == 422
    from bmt_backend.cursors import decode_cursor, encode_cursor
    cursor = decode_cursor(first["next_cursor"])
    cursor["generation"] = "old"
    assert d.client.get("/v1/track-of-the-day/lap-standings",
        params={**params, "cursor": encode_cursor(cursor)}).status_code == 422


def test_compact_snapshot_uses_indexed_flying_personal_bests(daily, monkeypatch):
    d = daily
    params = prepare(d, monkeypatch)
    for name, ticks in (("Alice", 120), ("Bob", 100), ("Carol", 150)):
        finish(d, ticks, name)
    bid = digest({"version_id": d.version.id, **board_manifest(d.version, "compact"), "comparison_population": "all"})
    laps = HistogramPopulation.from_frequencies([(20, 1), (24, 1), (30, 1)], own=None, stored_grid={"board_id": bid})
    monkeypatch.setattr("bmt_backend.histogram_snapshots.load_snapshot",
                        lambda *args: ("compact", {}, (HistogramPopulation.from_rows([]), laps)))
    response = d.client.get("/v1/track-of-the-day/lap-standings", params=params, headers=auth(d))
    assert response.status_code == 200, response.text
    assert [(row["display_name"], row["time_ticks"]) for row in response.json()["items"]] == [
        ("Bob", 20), ("Alice", 24), ("Carol", 30)]
    nearby = d.client.get("/v1/track-of-the-day/lap-standings",
        params={**params, "around": True, "lap_ticks": 25}, headers=auth(d)).json()
    assert [row["display_name"] for row in nearby["items"]] == ["Bob", "Carol"]
    assert nearby["comparison"]["position"] == 2 and nearby["comparison"]["population"] == 3
