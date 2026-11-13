# ruff: noqa: F811 - pytest injects the imported parametrized fixtures by name.
from test_daily_lap_standings import daily, prepare  # noqa: F401
from test_daily_standings import auth, auth_app, finish  # noqa: F401


def test_new_verified_driver_is_visible_before_small_snapshot_refresh(daily, monkeypatch):
    d = daily
    params = prepare(d, monkeypatch)
    # The snapshot has Alice at 2400 ticks, while verification commits a new PB.
    finish(d, 100, "Alice")
    response = d.client.get("/v1/track-of-the-day/lap-standings", params=params, headers=auth(d))
    assert response.status_code == 200, response.text
    data = response.json()
    assert data["player"]["time_ticks"] == 20
    assert data["player"]["rank"] == 1
    assert data["population"] == 4
    assert data["items"][0] == data["player"]
    # The immutable shared snapshot and other callers stay unchanged.
    public = d.client.get("/v1/track-of-the-day/lap-standings", params=params).json()
    assert next(row for row in public["items"] if row["display_name"] == "Alice")["time_ticks"] == 2400


def test_previously_absent_verified_driver_is_added_once(daily, monkeypatch):
    d = daily
    params = prepare(d, monkeypatch)
    from bmt_backend.histogram_population import HistogramPopulation
    from bmt_backend.runs import board_manifest
    from bmt_backend.track_models import digest
    board = digest({"version_id": d.version.id, **board_manifest(d.version, "compact"),
                    "comparison_population": "all"})
    laps = HistogramPopulation.from_rows([(d.identities["Bob"]["player"]["id"], 1200)], {"board_id": board})
    monkeypatch.setattr("bmt_backend.histogram_snapshots.load_snapshot",
                        lambda *args: ("before", {}, (HistogramPopulation.from_rows([]), laps)))
    finish(d, 100, "Alice")
    data = d.client.get("/v1/track-of-the-day/lap-standings", params=params, headers=auth(d)).json()
    assert data["population"] == 2
    assert [(row["display_name"], row["rank"]) for row in data["items"]] == [("Alice", 1), ("Bob", 2)]
    assert laps.cumulative[-1] == 1


def test_daily_partial_race_updates_standings_without_race_personal_best(daily, monkeypatch):
    d = daily
    params = prepare(d, monkeypatch)
    original = d.app.state.verifier.verify_run

    def verify(document, recording, vehicle_id, *, daily_laps=False, **options):
        if not daily_laps:
            return original(document, recording, vehicle_id, **options)
        # This test covers admission/finalization/projection. Native evidence
        # verification belongs to the canonical verifier tests.
        return {"manifest": d.app.state.verifier.validate_track(document),
                "time_ticks": 3600, "lap_ticks": [1800, 1200, 600]}

    monkeypatch.setattr(d.app.state.verifier, "verify_run", verify)
    issued = d.client.post("/v1/run-tickets", json={"version_id": d.version.id,
        "vehicle_id": "compact", "purpose": "daily_laps"}, headers=auth(d))
    assert issued.status_code == 201, issued.text
    from test_non_improving_runs import replay
    recording = replay([1800, 1200, 600])
    # Ordinary five-lap skip hints do not apply to the Daily evidence board.
    recording.pop("claimed_lap_ticks")
    submitted = d.client.post("/v1/runs", json={"ticket_id": issued.json()["ticket_id"],
        "replay": recording}, headers=auth(d))
    assert submitted.status_code == 202, submitted.text
    from bmt_backend.worker import process_one
    assert process_one(d.app)
    from bmt_backend.track_models import PersonalBest, Run
    with d.factory() as session:
        run = session.get(Run, submitted.json()["run_id"])
        assert run.status == "verified", run.failure_code
        assert session.get(PersonalBest, (run.board_id, run.player_id)) is None
    data = d.client.get("/v1/track-of-the-day/lap-standings", params=params, headers=auth(d)).json()
    assert data["player"]["time_ticks"] == 600
    assert data["player"]["rank"] == 1
    assert data["population"] == 4
