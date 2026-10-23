from pathlib import Path
import json
from types import SimpleNamespace
from bmt_backend.verifier import GodotVerifier, VerificationError
from bmt_backend.trajectory_verifier import check

root = Path.cwd()
verifier = GodotVerifier(SimpleNamespace(godot_bin=r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",game_project=root/"game",verifier_timeout_seconds=120))
document = json.loads((root/"game/tests/fixtures/star_spline_lap.json").read_text())
geometry = verifier.race_geometry(document)
path = json.loads((root/"build/star-checkpoint-consistency-2026-10-16/star-edge-five-lap-replay.json").read_text())
result = verifier.verify_canonical_diagnostic(document,path["replay"],"compact")
print("STAR_BACKEND_CANONICAL",result["time_ticks"],result["lap_ticks"],result["manifest"]["rules_key"])
print("STAR_SERVER_GATE_COUNT",len(geometry["gates"])-1)
(root/"docs/evidence/star-checkpoint-consistency-2026-10-16/backend-result.json").write_text(json.dumps(result,indent=2))
trajectories = json.loads((root/"docs/evidence/star-checkpoint-consistency-2026-10-16/trajectories.json").read_text())
legal = trajectories["legal"]
accepted = check(geometry,legal["proof"],legal["ticks"],"compact")
shortcut = trajectories["old_shortcut"]
old_geometry = {**geometry,"gates":trajectories["old_gates"]}
old_accepted = check(old_geometry,shortcut["proof"],shortcut["ticks"],"compact")
try:
    check(geometry,shortcut["proof"],shortcut["ticks"],"compact")
except VerificationError:
    print("STAR_SERVER_TRAJECTORIES legal=accepted old_shortcut=accepted new_shortcut=rejected")
else:
    raise AssertionError("Shortcut accepted by new server gates")
