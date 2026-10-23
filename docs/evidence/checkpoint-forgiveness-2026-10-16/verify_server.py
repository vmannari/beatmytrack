from pathlib import Path
from types import SimpleNamespace
import json
from bmt_backend.verifier import GodotVerifier, VerificationError
from bmt_backend.trajectory_verifier import check

root = Path.cwd()
evidence = root / "docs/evidence/checkpoint-forgiveness-2026-10-16"
verifier = GodotVerifier(SimpleNamespace(godot_bin=r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe",game_project=root/"game",verifier_timeout_seconds=120))
proofs = json.loads((evidence/"trajectories.json").read_text())
geometry = verifier.race_geometry(proofs["document"])
legal, bypass = proofs["legal"], proofs["old_shortcut"]
accepted = check(geometry,legal["proof"],legal["ticks"],"compact")
try:
    check(geometry,bypass["proof"],bypass["ticks"],"compact")
except VerificationError:
    rejected = True
else:
    raise AssertionError("Large shortcut accepted")
replay = json.loads((root/"build/star-checkpoint-consistency-2026-10-16/star-edge-five-lap-replay.json").read_text())
canonical = verifier.verify_canonical_diagnostic(proofs["document"],replay["replay"],"compact")
result = {"rules_key":geometry["manifest"]["rules_key"],"physics_version":geometry["manifest"]["physics_version"],"gates":len(geometry["gates"])-1,"legal_trajectory":"accepted","large_shortcut":"rejected","canonical_ticks":canonical["time_ticks"],"canonical_laps":canonical["lap_ticks"]}
(evidence/"server.json").write_text(json.dumps(result,indent=2))
print(json.dumps(result))
