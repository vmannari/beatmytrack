"""RCE04: reversible, byte-exact private checkpoint; preserve the shared index."""
import hashlib
import json
import re
import subprocess
from pathlib import Path
import road_checkpoint_efficiency_2026_11_17 as task

ROOT, WORK, OUT = task.base.ROOT, task.base.WORK, task.base.OUT
MARKER = "ROAD-CHECKPOINT-EFFICIENCY-20261117"
digest = lambda data: hashlib.sha256(data).hexdigest()
before, after = {}, {}
for path in (OUT / "before").rglob("*"):
    if not path.is_file():
        continue
    name = path.relative_to(OUT / "before").as_posix()
    current = ROOT / name
    if current.is_file() and current.read_bytes() != path.read_bytes():
        before[name], after[name] = path.read_bytes(), current.read_bytes()

names = ["native/track_geometry/checkpoint_geometry.hpp", "native/track_geometry/asphalt_sides.hpp",
         "docs/ROAD_CHECKPOINT_EFFICIENCY_2026_11_17.md", "scripts/checkpoint_road_efficiency.py",
         "scripts/road_checkpoint_efficiency_2026_11_17.py", "scripts/road_checkpoint_candidate_2026_11_17.py"]
for name in ["profile_road_checkpoint_kernels_2026_11_17.gd", "test_road_checkpoint_efficiency_2026_11_17.gd", "test_road_geometry_efficiency_2026_11_17.gd"]:
    names.append("game/tests/" + name)
    if (ROOT / (names[-1] + ".uid")).is_file(): names.append(names[-1] + ".uid")
descriptor = (ROOT / "game/platform/track_geometry/track_geometry.gdextension").read_text()
names += ["game/" + p for p in re.findall(r'= "res://([^"]+)"', descriptor)]
# Include the frozen source oracle, independent of disposable profiling copies.
names += [p.relative_to(ROOT).as_posix() for p in (OUT / "before/game").rglob("*.gd")]
for name in names: after[name] = (ROOT / name).read_bytes()

# Restore the previously referenced DLL as well as its descriptor on reversal.
old_descriptor = (OUT / "before/game/platform/track_geometry/track_geometry.gdextension").read_text()
old_name = re.search(r'windows.x86_64 = "res://([^"]+)"', old_descriptor).group(1)
old_leaf = Path(old_name).name
matches = list((ROOT / "archive/native-libraries").glob("*/" + old_leaf))
assert len(matches) == 1, matches
before["game/" + old_name] = matches[0].read_bytes()
assert not (ROOT / "game" / old_name).exists()
for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    after[name] = (ROOT / name).read_bytes()
    pattern = (r"<!-- " + MARKER + r" -->\r?\n.*?<!-- /" + MARKER + r" -->\r?\n(?:\r?\n)?").encode()
    before[name], count = re.subn(pattern, b"", after[name], flags=re.S)
    assert count == 1, name

private = WORK / "source-checkpoint"
assert private.resolve().is_relative_to(WORK.resolve()) and not private.exists()
private.mkdir(parents=True)
index = digest((ROOT / ".git/index").read_bytes())
def git(*args):
    result = subprocess.run(["git", "-c", "core.autocrlf=false", "-c",
        "core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol", *args], cwd=private, capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    return result.stdout
def write(files):
    for name, data in files.items():
        path = private / name
        path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)
git("init", "--quiet"); git("config", "user.name", "Local source checkpoint"); git("config", "user.email", "checkpoint@invalid.local")
write(before); git("add", "--all"); git("commit", "--quiet", "-m", "Exact sources and native libraries before RCE01-RCE04")
write(after)
for name in before.keys() - after.keys():
    path = private / name
    assert path.resolve().is_relative_to(private.resolve()); path.unlink()
git("add", "--all")
patch = git("diff", "--cached", "--binary", "--full-index", "HEAD")
patch_path = OUT / "source.patch"; patch_path.write_bytes(patch)
git("apply", "--check", "--reverse", str(patch_path)); git("apply", "--reverse", "--whitespace=error", str(patch_path))
for name in after.keys() | before.keys():
    path = private / name
    assert path.read_bytes() == before[name] if name in before else not path.exists(), name
git("apply", "--whitespace=error", str(patch_path))
for name in after.keys() | before.keys():
    path = private / name
    assert path.read_bytes() == after[name] if name in after else not path.exists(), name
git("diff", "--cached", "--check"); git("commit", "--quiet", "-m", "RCE01-RCE04 exact road and checkpoint preparation kernels")
bundle = WORK / "source-checkpoint.bundle"
git("bundle", "create", str(bundle), "--all"); git("bundle", "verify", str(bundle))
assert digest((ROOT / ".git/index").read_bytes()) == index
receipt = dict(commit=git("rev-parse", "HEAD").decode().strip(), forward_byte_exact=True,
    reverse_byte_exact=True, shared_index_unchanged=True, whitespace_check=True,
    patch_sha256=digest(patch), bundle=str(bundle.relative_to(ROOT)),
    files={name: dict(before=digest(before[name]) if name in before else None,
                     after=digest(after[name]) if name in after else None) for name in sorted(after.keys() | before.keys())})
(OUT / "source-checkpoint.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps({k: v for k, v in receipt.items() if k != "files"}, indent=2))
