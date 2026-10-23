"""Profile real warmed verification in an owned SQLite fixture, no live services.

Track geometry comes from the pinned native engine; actual worker acceptance
uses the retained public trajectory fixture and forbids engine invocation.
Numbers exclude upload/HTTP/cloud storage, and SQLite is not a capacity claim.
"""
import argparse
import cProfile
import importlib.util
import json
import logging
import pstats
import statistics
import subprocess
import time
from pathlib import Path

from bmt_backend.app import create_app
from bmt_backend.config import Settings
from bmt_backend.identity_models import Player
from bmt_backend.migrate import upgrade
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import (
    Board,
    OperationState,
    Run,
    RunTicket,
    Track,
    TrackVersion,
    digest,
    new_id,
    now,
)
from bmt_backend.verifier import GodotVerifier
from bmt_backend.worker import process_one
from sqlalchemy import event

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument("--label", default="baseline")
parser.add_argument("--iterations", type=int, default=20)
args = parser.parse_args()
folder = ROOT / "build" / "race-verification-2026-10-22" / (args.label + "-" + new_id())
folder.mkdir(parents=True)
spec = importlib.util.spec_from_file_location("stage_measure_verification", ROOT/"backend/deploy/stage_verifier.py")
stager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stager)
stager.stage(ROOT,folder/"game")
settings = Settings(environment="test", database_url="sqlite://", object_dir=str(folder/"objects"),
    godot_bin="C:/apps/Godot 4.7.2/Godot_v4.7.2-stable_win64_console.exe", game_project=str(folder/"game"),
    persistent_verifier=True)
imported = subprocess.run([settings.godot_bin,"--headless","--editor","--path",settings.game_project,"--import"],
                          capture_output=True,timeout=90,check=False)
(folder/"import.log").write_bytes(imported.stdout+imported.stderr)
assert imported.returncode == 0, (imported.stdout+imported.stderr).decode(errors="replace")
verifier = GodotVerifier(settings)
app = create_app(settings, verifier=verifier)
upgrade(app.state.engine)
logging.getLogger("bmt").setLevel(logging.ERROR)
fixture = json.loads((ROOT/"backend/tests/fixtures/verified_oval.json").read_text())
document = fixture["document"]
proof = json.loads((ROOT/"build/verification-speed-2026-10-09/proof.json").read_text())
proof = {"schema":"bmt-race-path-v1", "samples":[[s[0],s[1],s[2],s[6]] for s in proof["samples"]]}
geometry = verifier.race_geometry(document)
active = verifier.manifest()
replay = {"schema":"bmt-trajectory-v1","input_count":fixture["time_ticks"],"race_proof":proof}
accepted = verifier.verify_run(document,replay,"compact",geometry=geometry,capture_ghost=False)
assert accepted["time_ticks"] == fixture["time_ticks"]
assert accepted["lap_ticks"] == [2634,2532,2531,2530,2530]


def forbidden(*_args, **_kwargs):
    raise AssertionError("Warm verification attempted native execution")


verifier._invoke = forbidden
document_hash = app.state.blobs.put_json(document)
replay_hash = app.state.blobs.put_json(replay)
with app.state.session_factory() as db:
    player = Player(display_name="Verification performance fixture")
    db.add(player); db.flush()
    track = Track(owner_id=player.id)
    db.add(track); db.flush()
    version = TrackVersion(track_id=track.id,number=1,name="Verification fixture",content_hash=document_hash,
                           manifest=geometry["manifest"],state="published",published_at=now())
    db.add(version); db.flush()
    pinned = board_manifest(version,"compact")
    board = Board(id=digest({"version_id":version.id,**pinned}),version_id=version.id,vehicle_id="compact",manifest=pinned)
    db.add(board)
    db.add(OperationState(id="geom:"+document_hash,updated_at=now(),details=geometry))
    db.commit()
    player_id, board_id = player.id, board.id

timings, sql = {}, []


def measured(name, call):
    def wrapped(*positional, **named):
        start = time.perf_counter_ns()
        try:
            return call(*positional, **named)
        finally:
            timings.setdefault(name,[]).append((time.perf_counter_ns()-start)/1e6)
    return wrapped


original_read = app.state.blobs.get_json
def read(key):
    return measured("track_read" if key == document_hash else "replay_read",original_read)(key)
app.state.blobs.get_json = read
verifier.verify_run = measured("checker_adapter",verifier.verify_run)


def statement(_conn,_cursor,query,*_args):
    sql.append(query)


event.listen(app.state.engine,"before_cursor_execute",statement)
samples = []
profile = cProfile.Profile()
try:
    for index in range(args.iterations+2):
        with app.state.session_factory() as db:
            ticket = RunTicket(player_id=player_id,board_id=board_id,expires_at=now()+3600)
            db.add(ticket); db.flush()
            run = Run(player_id=player_id,board_id=board_id,ticket_id=ticket.id,replay_hash=replay_hash)
            db.add(run); db.commit()
            identity = run.id
        timings.clear(); sql.clear()
        started=time.perf_counter_ns()
        if index == args.iterations+1:
            profile.enable()
        assert process_one(app)
        profile.disable()
        elapsed=(time.perf_counter_ns()-started)/1e6
        count=len(sql)
        with app.state.session_factory() as db:
            result=db.get(Run,identity)
            assert result.status == "verified",(result.status,result.failure_code)
            assert (result.time_ticks,result.lap_ticks)==(12757,[2634,2532,2531,2530,2530])
        if 0 < index <= args.iterations:
            samples.append({"worker_ms":elapsed,"sql_statements":count,
                "geometry_reads":sum("FROM operation_state" in q and "WHERE operation_state.id =" in q for q in sql[:count]),
                **{name:sum(values) for name,values in timings.items()}})
    summary={key:statistics.median(row.get(key,0) for row in samples) for key in samples[0]}
    destination=Path(__file__).with_name(args.label+"-profile.json")
    destination.write_text(json.dumps({"label":args.label,"samples":samples,"medians":summary,
        "scope":"profiled warmed worker, real pinned-engine geometry and retained five-lap proof; no HTTP or cloud IO",
        "fixture_samples":len(proof["samples"]),"engine_calls_during_measured_acceptance":0},indent=2)+"\n")
    with Path(__file__).with_name(args.label+"-cprofile.txt").open("w") as stream:
        pstats.Stats(profile,stream=stream).strip_dirs().sort_stats("cumulative").print_stats(35)
    print(json.dumps(summary))
finally:
    event.remove(app.state.engine,"before_cursor_execute",statement)
    verifier.close()
    app.state.engine.dispose()
