"""Daily uploads verify flying laps without publishing partial race PBs."""
# ruff: noqa: F811 - pytest injects the imported parametrized fixtures by name.
import copy

import pytest
from sqlalchemy import select
from test_daily_lap_standings import prepare
from test_daily_standings import auth, auth_app, daily  # noqa: F401
from test_trajectory_integrity import course, path

from bmt_backend.daily_standings_models import DailyBest
from bmt_backend.identity_models import Player
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import PersonalBest, Run, digest
from bmt_backend.trajectory_verifier import check
from bmt_backend.verifier import VerificationError
from bmt_backend.worker import process_one


@pytest.mark.parametrize("count", [2, 3, 9, 10])
def test_daily_path_requires_whole_ordered_laps(count):
    geometry = course()
    geometry["start"] = [-0.055, 0, 0]
    samples = [[0, -0.055, 0, 0]] + [
        [tick, 0.055 if tick % 2 else -0.055, 0, 0] for tick in range(1, 2*count+1)]
    result = check(geometry, path(samples, False), 2*count, "compact", daily_laps=True)
    assert result["lap_ticks"] == [2]*count
    with pytest.raises(VerificationError):
        check(geometry, path(samples[:-1], False), 2*count-1, "compact", daily_laps=True)
    if count != 5:
        with pytest.raises(VerificationError):
            check(geometry, path(samples, False), 2*count, "compact")
    forged = copy.deepcopy(samples)
    forged[1][1] += 100
    with pytest.raises(VerificationError):
        check(geometry, path(forged, False), 2*count, "compact", daily_laps=True)


def test_opening_lap_alone_cannot_be_a_daily_score():
    geometry = course()
    geometry["start"] = [-0.055, 0, 0]
    with pytest.raises(VerificationError):
        check(geometry, path([[0,-0.055,0,0],[1,0.055,0,0],[2,-0.055,0,0]],False),
              2, "compact", daily_laps=True)


@pytest.mark.parametrize("compact", [False, True])
def test_daily_ticket_upload_worker_and_immediate_standings(daily, monkeypatch, compact):
    d = daily
    params = prepare(d, monkeypatch)
    if compact:
        from bmt_backend.histogram_population import HistogramPopulation
        laps = HistogramPopulation.from_frequencies([(1200,1),(2400,1),(3600,1),(6000,1)],
            stored_grid={"board_id": digest({
                "version_id":d.version.id, **board_manifest(d.version,"compact"),
                "comparison_population":"all"})})
        monkeypatch.setattr("bmt_backend.histogram_snapshots.load_snapshot",
            lambda *args: ("compact",{},(HistogramPopulation.from_rows([]),laps)))
    original = d.app.state.verifier
    def verify(document, replay, vehicle_id, *, daily_laps=False, **options):
        assert daily_laps and vehicle_id == "compact"
        return {"time_ticks":replay["input_count"],"lap_ticks":[100,2000],
                "manifest":original.validate_track(document)}
    monkeypatch.setattr(original,"verify_run",verify)
    ticket = d.client.post("/v1/run-tickets", json={"version_id":d.version.id,
        "vehicle_id":"compact","purpose":"daily_laps"}, headers=auth(d))
    assert ticket.status_code == 201, ticket.text
    issued = ticket.json()
    assert issued["manifest"]["laps"] == 10 and issued["manifest"]["daily_day"] == d.day
    replay = {"schema":"bmt-trajectory-v1","input_count":2100,
              "race_proof":{"schema":"bmt-race-path-v1","samples":[[0,0,0,0],[2100,0,0,0]]}}
    submitted = d.client.post("/v1/runs", json={"ticket_id":issued["ticket_id"],"replay":replay},headers=auth(d))
    assert submitted.status_code == 202, submitted.text
    assert process_one(d.app)
    with d.factory() as db:
        run = db.get(Run,submitted.json()["run_id"])
        assert run.status == "verified", run.failure_code
        assert db.get(PersonalBest,(run.board_id,run.player_id)) is None
        best = db.get(DailyBest,(d.day,run.board_id,run.player_id))
        assert best.time_ticks == 2000  # Never the quicker opening lap, never the total.
        assert len(db.scalars(select(DailyBest)).all()) == 1
    response = d.client.get("/v1/track-of-the-day/lap-standings",params=params,headers=auth(d))
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["player"]["time_ticks"] == 2000
    assert data["player"]["rank"] <= data["population"]
    assert sum(row["player_id"] == d.identities["Alice"]["player"]["id"] for row in data["items"]) == 1
    # Retry is idempotent and cannot create another completion or daily row.
    assert d.client.post("/v1/runs",json={"ticket_id":issued["ticket_id"],"replay":replay},headers=auth(d)).json()["status"] == "verified"
    with d.factory() as db:
        db.get(Player,d.identities["Alice"]["player"]["id"]).disabled = True
        db.commit()
    public = d.client.get("/v1/track-of-the-day/lap-standings",params=params).json()
    if compact:
        assert all(row["player_id"] != d.identities["Alice"]["player"]["id"] for row in public["items"])
