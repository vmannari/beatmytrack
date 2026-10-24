"""Make and verify an analysis-only Git checkpoint without touching the repo index."""
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
work = ROOT / "build/creator-object-limit"
work.mkdir(parents=True, exist_ok=True)
snapshot = Path(tempfile.mkdtemp(prefix="checkpoint-", dir=work))
verify = Path(tempfile.mkdtemp(prefix="verify-", dir=work))
paths = ["docs/CREATOR_OBJECT_LIMIT_2026_10_23.md",
         "game/tests/profile_creator_object_limit.gd",
         "game/tests/profile_creator_object_limit_higher.gd",
         "game/tests/profile_creator_object_limit_bootstrap.gd"]
paths += [str(p.relative_to(ROOT)).replace("\\", "/") for p in
          (ROOT / "game/tests").glob("profile_creator_object_limit*.uid")]
paths += [str((HERE/name).relative_to(ROOT)).replace("\\", "/")
          for name in ("run.ps1", "summarize.py", "checkpoint.py")]
paths.append("docs/evidence/creator-object-limit-higher-2026-10-23/index.py")

def git(directory, *args):
    return subprocess.run(["git", "-C", str(directory), *args], check=True, capture_output=True).stdout

for directory in (snapshot, verify):
    git(directory, "init", "--quiet", "--initial-branch=analysis")
    git(directory, "config", "core.autocrlf", "false")
for path in paths:
    target = snapshot/path
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT/path, target)
git(snapshot, "add", "--all")
git(snapshot, "-c", "user.name=Codex", "-c", "user.email=codex@local",
    "commit", "--quiet", "-m", "Analyze creator object capacity and tyre thresholds")
git(snapshot, "diff", "HEAD", "--check")
patch = HERE / "task-only.patch"
patch.write_bytes(git(snapshot, "format-patch", "--root", "--stdout", "HEAD"))
git(verify, "apply", "--check", str(patch))
git(verify, "apply", str(patch))
for path in paths:
    assert (verify/path).read_bytes() == (ROOT/path).read_bytes(), path
result = {"commit": git(snapshot, "rev-parse", "HEAD").decode().strip(),
          "snapshot": str(snapshot.relative_to(ROOT)), "verified": str(verify.relative_to(ROOT)),
          "patch_sha256": hashlib.sha256(patch.read_bytes()).hexdigest(),
          "files": paths, "apply_check": True, "exact_readback": True,
          "main_repository_index_untouched": True}
(HERE/"checkpoint.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
print(json.dumps(result))
