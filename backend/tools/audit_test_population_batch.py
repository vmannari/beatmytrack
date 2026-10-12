"""Read-only proof/PB audit for an explicitly authorized development batch."""
from __future__ import annotations

import argparse
import json
import statistics

from sqlalchemy import select

from bmt_backend.app import create_app
from bmt_backend.identity_models import Player
from bmt_backend.runs import PINNED_FIELDS
from bmt_backend.test_population_batch import batch_jobs, batch_view
from bmt_backend.track_models import Board, OperationState, PersonalBest, Run

PREFIX = "BMT_RESEED_AUDIT "


def audit(app, batch_id):
    settings = app.state.settings
    assert settings.environment == "development" and settings.test_drivers_enabled
    with app.state.session_factory() as session:
        view = batch_view(session, batch_id)
        assert view["complete"], "Audit requires every requested pair to be verified"
        data = session.get(OperationState, "test-pop-batch:"+batch_id).details
        jobs = batch_jobs(session, batch_id)
        player_ids = set(data["player_ids"])
        assert len(player_ids) == data["count"]
        players = {p.id: p for p in session.scalars(select(Player).where(Player.id.in_(player_ids)))}
        assert set(players) == player_ids and all(p.is_test_driver for p in players.values())
        runs = {r.id: r for r in session.scalars(select(Run).where(
            Run.id.in_([j.details["run_id"] for j in jobs])))}
        assert len(runs) == data["jobs"]
        boards = {b.id: b for b in session.scalars(select(Board).where(
            Board.id.in_({r.board_id for r in runs.values()})))}
        bests = {(p.board_id, p.player_id): p for p in session.scalars(select(PersonalBest).where(
            PersonalBest.board_id.in_(boards), PersonalBest.player_id.in_(player_ids)))}
        records = []
        for slot, entry in enumerate(data["tracks"]):
            rows = []
            selected = [j.details for j in jobs if j.details["slot"] == slot]
            assert len(selected) == data["count"]
            assert {j["player_id"] for j in selected} == player_ids
            for job in selected:
                run = runs[job["run_id"]]
                board = boards[run.board_id]
                assert run.status == "verified" and run.player_id == job["player_id"]
                assert len(run.lap_ticks) == 5 and sum(run.lap_ticks) == run.time_ticks
                assert run.time_ticks == job["time_ticks"]
                assert board.version_id == entry["version_id"] and board.vehicle_id == data["vehicle_id"]
                assert board.manifest.get("test_population") is True
                assert all(board.manifest.get(field) == data["manifest"][field] for field in PINNED_FIELDS)
                vehicle = data["manifest"]["vehicles"][data["vehicle_id"]]
                assert all(board.manifest.get(field) == vehicle[field]
                           for field in ("handling_version", "config_hash"))
                best = bests[(board.id, run.player_id)]
                assert best.time_ticks <= run.time_ticks
                rows.append({"player_id": run.player_id, "name": players[run.player_id].display_name,
                             "run_id": run.id, "time_ticks": run.time_ticks,
                             "lap_ticks": run.lap_ticks, "pb_time_ticks": best.time_ticks})
            values = [r["time_ticks"] for r in rows]
            records.append({"name": entry["name"], "version_id": entry["version_id"],
                            "verified_players": len(rows), "personal_bests": len(rows),
                            "minimum_ticks": min(values), "median_ticks": statistics.median(values),
                            "maximum_ticks": max(values), "distinct_times": len(set(values)),
                            "records": sorted(rows, key=lambda r: (r["time_ticks"], r["player_id"]))})
        return {"batch_id": batch_id, "test_population": True, "vehicle_id": data["vehicle_id"],
                "driver_count": len(player_ids), "track_count": len(records),
                "verified_runs": len(runs), "verified_personal_bests": sum(t["personal_bests"] for t in records),
                "laps_per_run": 5, "ticks_per_second": data["manifest"]["tick_rate"], "tracks": records}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("batch_id")
    args = parser.parse_args()
    app = create_app()
    try:
        report = audit(app, args.batch_id)
        # One bounded log entry per circuit avoids cloud-log entry truncation.
        for track in report.pop("tracks"):
            print(PREFIX+json.dumps({"kind": "track", **track}), flush=True)
        print(PREFIX+json.dumps({"kind": "summary", **report}), flush=True)
    finally:
        app.state.verifier.close()
        app.state.engine.dispose()


if __name__ == "__main__":
    main()
