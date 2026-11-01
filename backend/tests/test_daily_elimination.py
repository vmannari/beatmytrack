from test_daily_standings import auth, auth_app, feature  # noqa: F401
from test_daily_standings import daily as daily_fixture

from bmt_backend.daily_elimination import PERCENTILES, cutoffs
from bmt_backend.histogram_population import HistogramPopulation
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import digest
from bmt_backend.track_of_day import step

daily = daily_fixture


def test_nearest_rank_lap_cutoffs_and_ties():
    population = HistogramPopulation.from_rows([(str(i), i*120) for i in range(1, 101)])
    assert cutoffs(population) == [{"percentile": p, "lap_ticks": p*120} for p in PERCENTILES]
    assert cutoffs(HistogramPopulation.from_rows([])) == []
    assert {x["lap_ticks"] for x in cutoffs(HistogramPopulation.from_rows([("a", 1200)]))} == {1200}
    tied = HistogramPopulation.from_rows([("a", 1200), ("b", 1200), ("c", 2400)])
    assert [x["lap_ticks"] for x in cutoffs(tied)] == [2400] + [1200]*8


def test_limits_use_only_flying_laps_and_fence_daily_scope(daily, monkeypatch):
    d = daily
    feature(d)
    calls = []
    races = HistogramPopulation.from_rows([("a", 99999)])
    bid = digest({"version_id": d.version.id, **board_manifest(d.version, "compact"), "comparison_population": "all"})
    laps = HistogramPopulation.from_rows([(str(i), i*120) for i in range(1, 101)], {"board_id": bid})

    def snapshot(session, version, vehicle, artificial):
        calls.append((version, vehicle, artificial))
        return "generation-1", {}, (races, laps)

    monkeypatch.setattr("bmt_backend.histogram_snapshots.load_snapshot", snapshot)
    monkeypatch.setattr("bmt_backend.daily_fixed_limits.lap_population", lambda *args: laps)
    assert step(d.factory, clock=d.day*86400+10)
    params = {"day": d.day, "version_id": d.version.id, "vehicle_id": "compact"}
    response = d.client.get("/v1/track-of-the-day/limits", params=params)
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["cutoffs"] == [{"percentile": p, "lap_ticks": p*120} for p in PERCENTILES]
    assert data["manifest"]["vehicle_id"] == "compact"
    assert data["population"] == 100 and len(data["generation"]) == 64
    assert data["limits_set_at"] == d.day*86400+10
    assert response.headers["cache-control"] == "private, no-store"
    signed = d.client.get("/v1/track-of-the-day/limits", params=params, headers=auth(d))
    assert signed.json() == data
    assert d.client.get("/v1/track-of-the-day/limits", params={**params, "day": d.day-1}).status_code == 409
    assert d.client.get("/v1/track-of-the-day/limits", params={**params, "vehicle_id": "unknown"}).status_code == 422
    assert calls == []  # Limits reads do not load or recompute histogram snapshots.
    monkeypatch.setattr("bmt_backend.histogram_snapshots.load_snapshot", lambda *args: None)
    assert d.client.get("/v1/track-of-the-day/limits", params=params).json()["cutoffs"] == data["cutoffs"]
    monkeypatch.setattr("bmt_backend.histogram_snapshots.load_snapshot",
                        lambda *args: ("empty", {}, (races, HistogramPopulation.from_rows([], {"board_id": bid}))))
    assert d.client.get("/v1/track-of-the-day/limits", params=params).json()["generation"] == data["generation"]
