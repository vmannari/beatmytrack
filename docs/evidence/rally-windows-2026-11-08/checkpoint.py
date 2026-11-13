"""Create and round-trip a task-only Git checkpoint without touching the main index."""
import hashlib
import json
from pathlib import Path
import subprocess

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
private = root / "build/rally-windows-20261108/checkpoint"
private.mkdir(parents=True, exist_ok=True)
existing = [
    "game/vehicle/compact_coachwork.gd",
    "game/vehicle/compact_glazing.gd",
    "game/tests/test_compact_joints.gd",
    "game/assets/vehicles/compact_coachwork_v3/front_glass.res",
    "game/assets/vehicles/compact_coachwork_v3/front_seal.res",
    "game/assets/vehicles/racing_simple_v1/compact/front_glass_simple.res",
    "game/assets/vehicles/racing_simple_v1/compact/front_seal_simple.res",
]
new = [
    "game/tests/review_rally_windows.gd",
    "game/tests/bake_rally_glazing.gd",
    "game/tests/check_rally_prepared.gd",
    "docs/RALLY_WINDOWS_2026_11_08.md",
] + ["docs/evidence/rally-windows-2026-11-08/" + name for name in ("run_check.py", "refresh_prepared.py", "checkpoint.py")]

def digest(data):
    return hashlib.sha256(data).hexdigest()

def git(*args):
    return subprocess.check_output(["git", "-C", str(private), *args], stderr=subprocess.STDOUT)

root_index = root / ".git/index"
index_before = digest(root_index.read_bytes())
baseline = {}
origins = {}
for path in existing:
    snapshot = evidence / "before" / path
    if snapshot.exists():
        baseline[path] = snapshot.read_bytes()
        origins[path] = "saved before editing"
    else:
        baseline[path] = subprocess.check_output(["git", "-C", str(root), "show", "HEAD:" + path])
        origins[path] = "HEAD baseline for the two simple binary meshes"
    target = private / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(baseline[path])
(private / ".gitattributes").write_text("* -text\n")
git("init", "--initial-branch=task")
git("config", "user.name", "Codex")
git("config", "user.email", "codex@local.invalid")
git("config", "core.autocrlf", "false")
git("add", "--all")
git("commit", "--quiet", "-m", "Rally window source baseline")
base_commit = git("rev-parse", "HEAD").decode().strip()
final_bytes = {path: (root / path).read_bytes() for path in existing + new}
for path, data in final_bytes.items():
    target = private / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)
git("add", "--all")
git("commit", "--quiet", "-m", "Lower Rally side windows and refine the windshield")
commit = git("rev-parse", "HEAD").decode().strip()
patch = evidence / "task.patch"
patch.write_bytes(git("diff", "--binary", base_commit, commit))
git("apply", "--check", "--reverse", str(patch))
git("apply", "--reverse", str(patch))
assert all((private / path).read_bytes() == data for path, data in baseline.items())
assert all(not (private / path).exists() for path in new)
git("apply", str(patch))
assert all((private / path).read_bytes() == data for path, data in final_bytes.items())
assert digest(root_index.read_bytes()) == index_before
report = dict(commit=commit, baseline_commit=base_commit, root_index_unchanged=True, round_trip=True,
              files={path: dict(before=digest(baseline[path]) if path in baseline else None,
                                after=digest(data), baseline_origin=origins.get(path, "new file"))
                     for path, data in final_bytes.items()})
(evidence / "checkpoint.json").write_text(json.dumps(report, indent=2))
print(json.dumps(dict(commit=commit, files=len(final_bytes), round_trip=True, root_index_unchanged=True)))
