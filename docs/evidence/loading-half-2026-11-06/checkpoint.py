"""Reviewable task-only patch; apply and reverse only in a new owned repository."""
import difflib
import hashlib
import json
import os
import subprocess
import time
from pathlib import Path

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
ENV = {**os.environ, "GIT_OPTIONAL_LOCKS": "0"}
PREFIX = OUT.relative_to(ROOT).as_posix()
MARKER = "LOADING-HALF-20261106"
snapshots = {
    "game/core/app.gd": "before/game/core/app.gd",
    "game/soundtrack/audio_world.gd": "audio/before/game/soundtrack/audio_world.gd",
    "game/editor/editor_memory.gd": "race/editor_memory.before.gd",
    "game/track/prepared_world_cache.gd": "race/prepared_world_cache.before.gd",
    "game/ui/player_profile.gd": "graphics/before/game/ui/player_profile.gd",
    "backend/bmt_backend/track_of_day.py": "backend/before/backend/bmt_backend/track_of_day.py",
    "backend/bmt_backend/daily_fixed_limits.py": "backend/before/backend/bmt_backend/daily_fixed_limits.py",
    "native/biome_shader_profiles/README.md": "engine/native-readme-before-packaging.md",
}
before = {path: (OUT / snapshot).read_bytes() for path, snapshot in snapshots.items()}
build_helper = "native/biome_shader_profiles/build_android.py"
before[build_helper] = subprocess.check_output(["git", "show", "HEAD:" + build_helper], cwd=ROOT, env=ENV)
for path in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    data = (ROOT / path).read_bytes()
    start = data.index(("<!-- " + MARKER + " -->").encode())
    end = data.index(("<!-- /" + MARKER + " -->").encode(), start) + len("<!-- /" + MARKER + " -->")
    while data[end:end+1] in [b"\r", b"\n"]:
        end += 1
    before[path] = data[:start] + data[end:]
new = ["backend/bmt_backend/daily_snapshot_preparation.py", "backend/tests/test_daily_snapshot_preparation.py",
       "docs/LOADING_HALF_2026_11_06.md"]
new += ["game/tests/" + name + ".gd" for name in [
    "profile_loading_half", "profile_races_half",
    "profile_race_retention_policy", "test_race_effect_retention",
    "test_startup_audio_loading", "test_startup_selected_owner"]]
new += [p.relative_to(ROOT).as_posix() for p in OUT.rglob("*")
        if p.is_file() and p.suffix in {".py", ".ps1", ".gd", ".md"}
        and "before" not in p.relative_to(OUT).as_posix().lower()
        and "private-profile" not in p.parts]
new += [PREFIX + "/validation.json", PREFIX + "/evidence-files.json"]
new = sorted(set(new))
inventory = {p.relative_to(ROOT).as_posix(): {"bytes": p.stat().st_size,
              "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
             for p in OUT.rglob("*") if p.is_file()
             and p.name not in {"task.patch", "checkpoint.json", "evidence-files.json"}
             and "private-profile" not in p.parts and "__pycache__" not in p.parts}
(OUT / "evidence-files.json").write_text(json.dumps(inventory, indent=2) + "\n", encoding="utf-8")
after = {path: (ROOT / path).read_bytes() for path in list(before) + new}
owned = ROOT / "build/loading-half-20261106" / ("checkpoint-" + str(time.time_ns()))
owned.mkdir(parents=True)
subprocess.run(["git", "init", "--quiet", str(owned)], check=True, env=ENV)
patch = []
for path, data in after.items():
    original = before.get(path, b"")
    if path in before:
        destination = owned / path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(original)
    patch.append("".join(difflib.unified_diff(original.decode("utf-8").splitlines(True),
                  data.decode("utf-8").splitlines(True),
                  fromfile="a/" + path if path in before else "/dev/null", tofile="b/" + path)))
patch_path = OUT / "task.patch"
patch_path.write_bytes("".join(patch).encode("utf-8"))
commands = []


def git(*args):
    command = ["git", "-C", str(owned), "-c", "core.autocrlf=false", "-c", "core.eol=lf",
               "-c", "core.whitespace=trailing-space,space-before-tab,cr-at-eol", *args]
    result = subprocess.run(command, capture_output=True, text=True, env=ENV, check=False)
    commands.append({"command": command, "exit_code": result.returncode, "stdout": result.stdout, "stderr": result.stderr})
    if result.returncode:
        (OUT / ("checkpoint-failure-" + str(time.time_ns()) + ".json")).write_text(json.dumps(commands, indent=2))
        raise RuntimeError(result.stderr)


git("apply", "--check", "--whitespace=error", str(patch_path))
git("apply", "--whitespace=error", str(patch_path))
for path, data in after.items():
    assert (owned / path).read_bytes() == data, path
git("apply", "--reverse", "--check", str(patch_path))
git("apply", "--reverse", str(patch_path))
for path, data in before.items():
    assert (owned / path).read_bytes() == data, path
for path in new:
    assert not (owned / path).exists(), path
result = {"files": len(after), "changed": list(before), "new": new, "scratch_repository": str(owned),
              "patch_sha256": hashlib.sha256(patch_path.read_bytes()).hexdigest(),
              "forward_byte_exact": True, "reverse_byte_exact": True, "commands": commands,
              "main_repository_staged_or_committed": False,
              "before_note": "Exact saved snapshots except build_android.py reconstructed from HEAD; journal bases remove only this task's block from current concurrent content.",
              "main_index_note": "Index metadata changed earlier during inspection; this checkpoint operates only in its owned repository."}
(OUT / "checkpoint.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
print(json.dumps({k: v for k, v in result.items() if k not in {"commands", "new", "changed"}}, indent=2))
