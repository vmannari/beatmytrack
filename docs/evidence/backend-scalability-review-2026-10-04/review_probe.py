"""Read-only source audit with disposable fixtures; never connects to deployed services.

Run from repository root with .tools/backend-venv/Scripts/python.exe <this file>.
Measurements use SQLite/Windows and are not NAS/PostgreSQL capacity claims.
"""
import gc
import gzip
import json
import os
import statistics
import subprocess
import sys
import tempfile
import time
import tracemalloc
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend/tests"))

from fastapi.testclient import TestClient
from sqlalchemy import event, text
from test_domains import FakeVerifier

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.middleware import parse_body
from bmt_backend.migrate import upgrade
from bmt_backend.rivalry import eligible_versions, skill_score, snapshot
from bmt_backend.rivalry_models import RivalryBest, RivalryGroup, RivalryMember, RivalryTicket
from bmt_backend.runs import board_manifest
from bmt_backend.storage import canonical_json
from bmt_backend.track_models import Board, PersonalBest, Run, RunTicket, Track, TrackVersion, digest, now
from bmt_backend.verifier import GodotVerifier, VerifierUnavailable
from bmt_backend.worker import process_one


def sizes(value):
    body = canonical_json(value)
    return {"json_bytes": len(body), "gzip_bytes": len(gzip.compress(body, mtime=0))}


def rle(frames):
    result = []
    for frame in frames:
        if result and result[-1][1] == frame:
            result[-1][0] += 1
        else:
            result.append([1, frame])
    return result


def main():
    output = {"scope": "disposable SQLite fixtures and exact Windows engine; no live traffic"}
    # Keep engine logs inside the workspace, independently of the desktop profile.
    profile = ROOT / "build/backend-review-appdata"
    profile.mkdir(parents=True, exist_ok=True)
    os.environ["APPDATA"] = str(profile)
    fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())
    replay = fixture["replay"]
    output["golden_replay"] = {"frames": len(replay["frames"]), "seconds": len(replay["frames"]) / 120,
                               **sizes(replay), "rle": sizes({"frames": rle(replay["frames"])})}
    frames = [[*frame, 0] if len(frame) == 3 else frame for frame in replay["frames"]]
    output["golden_four_channel_replay"] = sizes({"schema": replay["schema"], "frames": frames})
    output["golden_document"] = sizes(fixture["document"])
    maximum = canonical_json({"schema": "bmt-replay-v1", "frames": [[-127, 255, 255, 255]] * 216000})
    gc.collect()
    tracemalloc.start()
    start = time.perf_counter()
    parsed = parse_body(maximum)
    retained, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    output["max_four_channel_parse"] = {"bytes": len(maximum), "peak_traced_bytes": peak,
                                        "retained_traced_bytes":retained,
                                        "seconds_instrumented": time.perf_counter() - start,
                                        "note": "parse allocation only; excludes transport, validation, hashing and encoding"}
    del parsed, maximum
    with tempfile.TemporaryDirectory(prefix="bmt-review-", dir=ROOT / "build") as folder:
        app = create_app(Settings(database_url=f"sqlite:///{Path(folder).as_posix()}/db.sqlite",
                                  object_dir=str(Path(folder) / "objects")), verifier=FakeVerifier())
        upgrade(app.state.engine)
        queries = []
        with app.state.engine.connect() as connection:
            output["sqlite_migrated_triggers"] = list(connection.scalars(text("SELECT name FROM sqlite_master WHERE type='trigger' ORDER BY name")))

        @event.listens_for(app.state.engine, "before_cursor_execute")
        def capture(_connection, _cursor, statement, _parameters, _context, _many):
            queries.append(statement)

        with app.state.session_factory() as session:
            drivers = [Player(display_name=f"ReviewDriver{i:02}") for i in range(20)]
            session.add_all(drivers)
            session.flush()
            ids = [player.id for player in drivers]
            slots = []
            boards = []
            for index in range(20):
                track = Track(owner_id=ids[0], official=True)
                session.add(track)
                session.flush()
                doc = {"shape": "oval", "id": f"review_{index}", "name": f"Review Track {index}",
                       "points": [[round(i * 1.112233, 6), round(i * 0.887766, 6)] for i in range(96)]}
                version = TrackVersion(track_id=track.id, number=1, name=doc["name"], state="published",
                                       published_at=now(), content_hash=app.state.blobs.put_json(doc),
                                       manifest=app.state.verifier.validate_track(doc),
                                       discovery={"theme": "pine", "points": doc["points"]})
                session.add(version)
                session.flush()
                pinned = board_manifest(version, "compact")
                board_id = digest({"version_id": version.id, **pinned})
                session.add(Board(id=board_id, version_id=version.id, vehicle_id="compact", manifest=pinned))
                session.flush()
                boards.append(board_id)
                for ordinal, pid in enumerate(ids):
                    ticket = RunTicket(player_id=pid, board_id=board_id, expires_at=now() + 7200)
                    session.add(ticket)
                    session.flush()
                    run = Run(ticket_id=ticket.id, player_id=pid, board_id=board_id,
                              replay_hash="0" * 64, status="verified", time_ticks=12000 + ordinal,
                              finished_at=now())
                    session.add(run)
                    session.flush()
                    session.add(PersonalBest(board_id=board_id, player_id=pid, run_id=run.id,
                                             time_ticks=run.time_ticks))
                    if index < 5:
                        slots.append((index, pid, run.id, run.time_ticks))
            session.commit()
        with TestClient(app) as client:
            page = client.get("/v1/tracks?limit=100")
            assert page.status_code == 200
            output["discovery_page"] = {"items": len(page.json()["items"]), "wire_bytes": len(page.content), **sizes(page.json())}
            with app.state.session_factory() as session:
                selected = [session.get(Board, identity).version_id for identity in boards[:5]]
                entries = [next(e for e in page.json()["items"] if e["version_id"] == identity) for identity in selected]
                # Use five distinct circuits; all have the same bounded 96-point projection.
                group = RivalryGroup(week_start=now() - 3600, ends_at=now() + 3600, vehicle_id="compact",
                                     contract_key="review", skill_band=-1, member_count=20,
                                     tracks=[{"version_id": e["version_id"], "board_id": boards[i],
                                              "tick_rate":120, "entry":e} for i, e in enumerate(entries)])
                session.add(group)
                session.flush()
                group_id = group.id
                for pid in ids:
                    session.add(RivalryMember(group_id=group_id, player_id=pid, week_start=group.week_start, contract_key="review"))
                for slot, pid, run_id, ticks in slots:
                    session.add(RivalryBest(group_id=group_id, player_id=pid, slot=slot, run_id=run_id, time_ticks=ticks))
                session.commit()
            with app.state.session_factory() as session:
                group = session.get(RivalryGroup, group_id)
                queries.clear()
                value = snapshot(session, group, ids[1])
                output["rivalry_snapshot"] = {**sizes(value), "sql_statements": len(queries), "drivers": 20}
            with app.state.session_factory() as session:
                queries.clear()
                skill = skill_score(session, ids[1], "compact", app.state.verifier.manifest(), now())
                output["rivalry_skill"] = {"value":skill, "boards":20, "sql_statements":len(queries)}
                queries.clear()
                eligible = eligible_versions(session, app.state.verifier.manifest(), "compact")
                output["eligibility"] = {"candidates":len(eligible), "sql": list(queries)}
            with app.state.session_factory() as session:
                race_ticket = RunTicket(player_id=ids[1], board_id=boards[0], expires_at=now() + 7200)
                session.add(race_ticket)
                session.flush()
                run = Run(ticket_id=race_ticket.id, player_id=ids[1], board_id=boards[0],
                          replay_hash=app.state.blobs.put_json({"schema":"bmt-replay-v1", "frames":[[0,255,0]] * 20}))
                session.add(run)
                session.flush()
                run_id = run.id
                session.add(RivalryTicket(ticket_id=race_ticket.id, group_id=group_id, slot=0))
                session.commit()
            # Inject the EROFS expected from the production read-only volume only for ghost writes.
            original = app.state.blobs.put_json

            def read_only_ghost(value):
                if "poses" in value:
                    raise OSError(30, "Read-only file system")
                return original(value)

            verify = app.state.verifier.verify_run

            def with_ghost(*args, **kwargs):
                return {**verify(*args, **kwargs), "ghost":{"poses":[[0,0,0,0,0,0,0]], "ticks":100}}

            with patch.object(app.state.blobs, "put_json", read_only_ghost), patch.object(app.state.verifier, "verify_run", with_ghost):
                try:
                    process_one(app)
                    output["readonly_worker_reproduction"] = {"raised":False}
                except OSError as error:
                    with app.state.session_factory() as session:
                        saved = session.get(Run, run_id)
                        output["readonly_worker_reproduction"] = {"raised":True, "errno":error.errno,
                                                                  "run_status":saved.status, "attempts":saved.attempts}
        app.state.engine.dispose()
    binary = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    if binary.is_file():
        verifier = GodotVerifier(SimpleNamespace(godot_bin=str(binary), game_project=ROOT / "game", verifier_timeout_seconds=90))
        times = []
        run_process = subprocess.run

        def workspace_log(command, **kwargs):
            # Windows Godot resolves its log directory via a known-folder API,
            # independently of APPDATA. Only redirect diagnostics; exact engine,
            # canonical runner, source and fixture remain unchanged.
            if "--script" in command:
                command = [*command[:1], "--log-file", str(ROOT / "build/backend-review-engine.log"), *command[1:]]
            return run_process(command, **kwargs)

        try:
            with patch("bmt_backend.verifier.subprocess.run", workspace_log):
                for _ in range(3):
                    start = time.perf_counter()
                    result = verifier.verify_run(fixture["document"], replay, fixture["vehicle_id"])
                    assert result["time_ticks"] == fixture["time_ticks"]
                    times.append(time.perf_counter() - start)
            output["canonical_golden_verification"] = {"seconds":times, "median_seconds":statistics.median(times),
                                                        "ghost":sizes(result["ghost"]),
                                                        "poses":len(result["ghost"]["poses"])}
        except VerifierUnavailable as error:
            output["canonical_golden_verification"] = {"error": str(error), "passed":False}
    target = Path(__file__).with_name("measurements.json")
    target.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k:v for k,v in output.items() if k != "eligibility"}, indent=2))


if __name__ == "__main__":
    main()
