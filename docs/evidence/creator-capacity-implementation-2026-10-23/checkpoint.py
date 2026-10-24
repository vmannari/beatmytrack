"""Build a checked capacity-only patch while preserving concurrent source edits."""
import difflib
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
BEFORE = HERE / "before"

def put(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)

def reverse(path, replacements):
    target = BEFORE / path
    if target.exists():
        return
    source = (ROOT / path).read_text(encoding="utf-8")
    for after, before in replacements:
        assert after in source, (path, after)
        source = source.replace(after, before)
    put(target, source.encode())

# Reconstruct the small adjacent changes whose originals were not snapshotted.
# All other originals were captured before the first edit and remain untouched.
reverse("game/editor/spatial_bounds.gd", [
    ("var cell: float = CELL\n\nfunc _init(size: float = CELL) -> void: cell = maxf(0.5,size)\n", ""),
    ("/cell", "/CELL")])
reverse("game/vehicle/speed_bumps.gd", [
    (", has_distant_bumps: bool = false", ""),
    ("if objects.is_empty() and not has_distant_bumps:", "if objects.is_empty():")])
reverse("game/race/personal_ghost_run.gd", [
    ("track.ramp_height(point)", "TrackHazards.ramp_height(point,track.hazard_objects)"),
    ("track.ramp_pitch(point,axle.normalized())", "TrackHazards.ramp_pitch(point,axle.normalized(),track.hazard_objects)")])
reverse("game/track/contact_shading.gd", [
    ("track.ramp_height(point+axle)", "TrackHazards.ramp_height(point+axle,track.hazard_objects)"),
    ("track.ramp_height(point-axle)", "TrackHazards.ramp_height(point-axle,track.hazard_objects)")])
reverse("backend/deploy/stage_verifier.py", [
    ('        "'+name+'",\n', "") for name in (
        "creator_limits", "creator_prop_costs", "spatial_bounds", "road_piece_catalog",
        "road_update", "road_sections", "creator_queries")
] + [(', "attempt_evidence"', "")])
reverse("docs/CREATOR_OBJECT_LIMIT_2026_10_23.md", [
    ("\nHistorical baseline: the owner subsequently approved and implemented the [4,096-object capacity package](CREATOR_CAPACITY_2026_10_23.md). The measurements below describe the captured pre-implementation state.\n", "")])

def foundation(path):
    old = (BEFORE / path).read_bytes()
    new = (ROOT / path).read_bytes()
    if path == "AGENTS.md":
        return old
    newline = "\r\n" if b"\r\n" in new else "\n"
    old_text = old.decode().replace("\r\n", "\n")
    new_text = new.decode().replace("\r\n", "\n")
    # These files received independent edits after the initial capture. Keep
    # those edits in the foundation; reverse only the capacity-related hunks.
    tokens = {
        "game/core/app.gd": ("creator_limits.gd", "addition_error"),
        "game/core/game.gd": ("TrackHazards.ramp_",),
        "game/track/native_track_visual.gd": ("tyre_batches.gd", 'has_method("set_pose")'),
    }.get(path)
    if not tokens:
        return old_text.replace("\n", newline).encode()
    a, b = old_text.splitlines(True), new_text.splitlines(True)
    groups = list(difflib.SequenceMatcher(None, a, b, autojunk=False).get_grouped_opcodes(2))
    for group in reversed(groups):
        i1, i2, j1, j2 = group[0][1], group[-1][2], group[0][3], group[-1][4]
        if any(token in "".join(a[i1:i2]+b[j1:j2]) for token in tokens):
            b[j1:j2] = a[i1:i2]
    return "".join(b).replace("\n", newline).encode()

existing = sorted(str(p.relative_to(BEFORE)).replace("\\", "/") for p in BEFORE.rglob("*")
                  if p.is_file() and (ROOT / p.relative_to(BEFORE)).is_file()
                  and foundation(str(p.relative_to(BEFORE)).replace("\\", "/")) != (ROOT / p.relative_to(BEFORE)).read_bytes())
new = ["game/editor/creator_limits.gd", "game/editor/creator_prop_costs.gd",
       "game/track/tyre_batches.gd", "game/vehicle/creator_queries.gd",
       "game/tests/test_creator_capacity.gd", "game/tests/bake_creator_prop_costs.gd",
       "backend/tests/test_creator_capacity.py", "docs/CREATOR_CAPACITY_2026_10_23.md"]
new += [path+".uid" for path in new if path.endswith(".gd") and (ROOT / (path+".uid")).exists()]
new += [str((HERE / name).relative_to(ROOT)).replace("\\", "/")
        for name in ("run.ps1", "canonical.py", "checkpoint.py", "report.py")]
# The paired test dynamically loads precisely these original implementations.
new += [str((BEFORE / name).relative_to(ROOT)).replace("\\", "/")
        for name in ("game/editor/placed_object_batches.gd", "game/track/native_track_visual.gd")]
paths = existing + new
assert len(paths) == len(set(paths))

work = ROOT / "build/creator-capacity"
snapshot = Path(tempfile.mkdtemp(prefix="checkpoint-", dir=work))
verify = Path(tempfile.mkdtemp(prefix="verify-", dir=work))

def git(directory, *args):
    return subprocess.run(["git", "-C", str(directory), *args], check=True, capture_output=True).stdout

for directory in (snapshot, verify):
    git(directory, "init", "--quiet", "--initial-branch=capacity")
    git(directory, "config", "core.autocrlf", "false")
    git(directory, "config", "core.whitespace", "cr-at-eol")
    for path in existing:
        put(directory / path, foundation(path))
    git(directory, "add", "--all")
    git(directory, "-c", "user.name=Codex", "-c", "user.email=codex@local",
        "commit", "--quiet", "-m", "Captured foundation with independent concurrent work preserved")
for path in paths:
    put(snapshot / path, (ROOT / path).read_bytes())
git(snapshot, "add", "--all")
git(snapshot, "diff", "--cached", "--check")
git(snapshot, "-c", "user.name=Codex", "-c", "user.email=codex@local",
    "commit", "--quiet", "-m", "Raise creator capacity with bounded tyres, geometry and incremental work")
patch = HERE / "task-only.patch"
patch.write_bytes(git(snapshot, "format-patch", "-1", "--stdout", "HEAD"))
git(verify, "apply", "--check", str(patch))
git(verify, "apply", str(patch))
for path in paths:
    assert (verify / path).read_bytes() == (ROOT / path).read_bytes(), path
result = {"commit": git(snapshot, "rev-parse", "HEAD").decode().strip(),
          "snapshot": str(snapshot.relative_to(ROOT)), "verified": str(verify.relative_to(ROOT)),
          "patch_sha256": hashlib.sha256(patch.read_bytes()).hexdigest(), "files": paths,
          "apply_check": True, "exact_readback": True, "main_repository_index_untouched": True,
          "scope": "Capacity hunks only; unrelated later App/game/road-cache edits are in the foundation.",
          "source_sha256": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}}
(HERE / "checkpoint.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
print(json.dumps({k: v for k, v in result.items() if k not in ("source_sha256", "files")}))
