"""Build a review patch containing only this task, then prove its round trip."""
import difflib
import hashlib
import json
import re
import subprocess
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
baseline = {}
current = {}


def capture(name, before):
    assert name not in current
    baseline[name] = before
    current[name] = (ROOT/name).read_text(encoding="utf-8")


for source in (EVIDENCE/"before-source").glob("*.txt"):
    name = source.name.removesuffix(".txt").replace("__", "/")
    if name.startswith("game/localization/"):
        # Remove only our appended messages. Preserve all concurrent catalog work.
        after = (ROOT/name).read_text(encoding="utf-8")
        before, count = re.subn(r"(?m)^#: game/ui/daily_standings\.gd\nmsgid [^\n]+\nmsgstr [^\n]*\n(?:\n|$)", "", after)
        assert count == 8, (name, count)
        capture(name, before)
    else:
        capture(name, source.read_text(encoding="utf-8"))

for name in ("AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"):
    after = (ROOT/name).read_text(encoding="utf-8")
    before, count = re.subn(r"<!-- TRACK-OF-DAY-STANDINGS-20261028 -->\n.*?<!-- /TRACK-OF-DAY-STANDINGS-20261028 -->\n\n", "", after, flags=re.S)
    assert count == 1
    capture(name, before)

new_files = [
    "backend/bmt_backend/daily_standings.py",
    "backend/bmt_backend/daily_standings_models.py",
    "backend/bmt_backend/migrations/versions/0071_track_of_day_bests.py",
    "backend/tests/test_daily_standings.py",
    "backend/tests/test_daily_standings_native.py",
    "backend/schemas/track-of-day-standings-v1.schema.json",
    "game/ui/daily_standings.gd", "game/ui/daily_standings.gd.uid",
    "game/tests/test_daily_standings.gd", "game/tests/test_daily_standings.gd.uid",
    "game/tests/test_daily_standings_http.gd",
    "scripts/translations/daily_standings.tsv",
    "docs/TRACK_OF_DAY_STANDINGS_2026_10_28.md",
    *[EVIDENCE.relative_to(ROOT).as_posix()+"/"+name for name in (
        "run.ps1", "run_backend.py", "postgres_lab.py", "checkpoint.py")],
]
for name in new_files:
    capture(name, None)

patch = "".join("".join(difflib.unified_diff(
    (baseline[name] or "").splitlines(keepends=True), current[name].splitlines(keepends=True),
    fromfile="/dev/null" if baseline[name] is None else "a/"+name,
    tofile="b/"+name)) for name in sorted(current))
patch_path = EVIDENCE/"source.patch"
patch_path.write_text(patch, encoding="utf-8", newline="\n")


def git(*arguments):
    result = subprocess.run(["git", "apply", *arguments, str(patch_path)], cwd=ROOT,
                            text=True, capture_output=True)
    return {"exit_code": result.returncode, "output": result.stdout+result.stderr}


actual_reverse = git("--reverse", "--check")
scratch = ROOT/"build"/("daily-standings-checkpoint-"+uuid.uuid4().hex[:10])
scratch.mkdir(parents=True)
for name, before in baseline.items():
    if before is not None:
        target = scratch/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(before, encoding="utf-8", newline="\n")
prefix = "--directory="+scratch.relative_to(ROOT).as_posix()
forward_check = git("--check", prefix)
assert forward_check["exit_code"] == 0, forward_check
forward = git(prefix)
assert forward["exit_code"] == 0, forward
assert all((scratch/name).read_text(encoding="utf-8") == value for name, value in current.items())
reverse = git("--reverse", prefix)
assert reverse["exit_code"] == 0, reverse
assert all(not (scratch/name).exists() if before is None else
           (scratch/name).read_text(encoding="utf-8") == before for name, before in baseline.items())
result = {"actual_reverse_check": actual_reverse, "isolated_forward_check": forward_check,
          "isolated_forward": forward, "isolated_reverse": reverse,
          "isolated_exact_round_trip": True, "files": len(current),
          "patch_sha256": hashlib.sha256(patch_path.read_bytes()).hexdigest(),
          "file_sha256": {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in sorted(current)}}
(EVIDENCE/"checkpoint.json").write_text(json.dumps(result, indent=2)+"\n", encoding="utf-8")
print(json.dumps({key: value for key, value in result.items() if key != "file_sha256"}, indent=2))
