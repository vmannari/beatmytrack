"""Real prepared geometry and worker acceptance under an unchanged car's old pin."""
import importlib.util
import json
import shutil
import subprocess
from copy import deepcopy
from pathlib import Path
from types import SimpleNamespace

import pytest
from test_domains import domain as domain_fixture
from test_domains import headers

from bmt_backend.track_models import Board, PersonalBest, Run, Track, TrackVersion
from bmt_backend.verifier import GodotVerifier
from bmt_backend.worker import process_one

domain = domain_fixture
ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture(scope="module")
def native_case(tmp_path_factory):
    binary = Path(r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe")
    if not binary.is_file():
        pytest.skip("Pinned Godot unavailable")
    folder = tmp_path_factory.mktemp("native-compatibility")
    project = folder / "game"
    spec = importlib.util.spec_from_file_location("stage_car_compatibility",ROOT / "backend/deploy/stage_verifier.py")
    stage = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(stage)
    stage.stage(ROOT,project)
    (project / "tests").mkdir()
    shutil.copyfile(ROOT / "game/tests/test_lightweight_verifier.gd",project / "tests/test_lightweight_verifier.gd")
    imported = subprocess.run([str(binary),"--headless","--path",str(project),"--editor","--import",
        "--log-file",str(folder / "import.log")],capture_output=True,text=True,timeout=90,check=False)
    assert imported.returncode == 0, imported.stdout+imported.stderr
    output = folder / "proof.json"
    generated = subprocess.run([str(binary),"--headless","--path",str(project),"--script",
        "res://tests/test_lightweight_verifier.gd","--log-file",str(folder / "record.log"),"--",
        f"--fixture={ROOT / 'backend/tests/fixtures/verified_oval.json'}",f"--proof-output={output}"],
        capture_output=True,text=True,timeout=90,check=False)
    assert generated.returncode == 0, generated.stdout+generated.stderr
    verifier = GodotVerifier(SimpleNamespace(godot_bin=str(binary),game_project=project,verifier_timeout_seconds=90))
    fixture = json.loads((ROOT / "backend/tests/fixtures/verified_oval.json").read_text())
    try:
        yield verifier, fixture, json.loads(output.read_text())
    finally:
        verifier.close()


@pytest.mark.godot
@pytest.mark.parametrize("tampered",[False,True])
def test_native_worker_keeps_old_compact_board_and_enforces_real_path(domain,native_case,tampered):
    verifier, fixture, proof = native_case
    domain.app.state.verifier = verifier
    manifest = verifier.validate_track(fixture["document"])
    old = deepcopy(manifest)
    old["physics_version"] = "arcade-planar-0.74"
    old["vehicles"]["electric"] = {"handling_version":"electric-17",
        "config_hash":"4ce920bc320196a5556c6e11407b299aac6c2078fecd8ac221e5a4a612750359"}
    content = domain.app.state.blobs.put_json(fixture["document"])
    with domain.factory() as db:
        track = Track(owner_id=domain.players["Creator"],official=True)
        db.add(track)
        db.flush()
        version = TrackVersion(track_id=track.id,number=1,name="Native compatibility oval",state="published",
            content_hash=content,manifest=old,discovery={"theme":"pine","points":fixture["document"]["points"]})
        db.add(version)
        db.flush()
        version_id = version.id
        db.commit()
    issued = domain.client.post("/v1/run-tickets",json={"version_id":version_id,"vehicle_id":"compact"},
                                headers=headers(domain,"Alice"))
    assert issued.status_code == 201, issued.text
    ticket = issued.json()
    recording = deepcopy(proof)
    if tampered:
        recording["samples"][1][1] += 40
    submitted = domain.client.post("/v1/runs",json={"ticket_id":ticket["ticket_id"],
        "replay":{"schema":"bmt-trajectory-v1","input_count":fixture["time_ticks"],"race_proof":recording}},
        headers=headers(domain,"Alice"))
    assert submitted.status_code == 202, submitted.text
    assert process_one(domain.app)
    with domain.factory() as db:
        run = db.get(Run,submitted.json()["run_id"])
        assert run.status == ("rejected" if tampered else "verified")
        assert run.failure_code == ("invalid_replay" if tampered else None)
        assert db.get(Board,ticket["board_id"]).manifest == ticket["manifest"]
        assert ticket["manifest"]["physics_version"] == "arcade-planar-0.74"
        assert db.get(TrackVersion,version_id).manifest == old
        best = db.get(PersonalBest,(ticket["board_id"],domain.players["Alice"]))
        if tampered:
            assert best is None
        else:
            assert best.run_id == run.id and best.time_ticks == 12757
            assert run.lap_ticks == [2634,2532,2531,2530,2530]
