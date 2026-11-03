"""Task-only patch and content round trips; no main Git index writes."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
base = evidence / "checkpoint-base"
changed = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "game/core/app.gd",
           "game/editor/editor_memory.gd", "game/race/selected_track_preparation.gd",
           "game/track/prepared_world_cache.gd", "game/vehicle/effect_preparation_pool.gd",
           "game/vehicle/effect_render_preparation.gd", "game/tests/test_runtime_loading_fixes.gd",
           "game/tests/test_runtime_effect_loading.gd"]
prefix = "docs/evidence/race-loading-implementation-2026-11-02/"
added = ["docs/RACE_LOADING_IMPLEMENTATION_2026_11_02.md",
         "game/tests/test_race_loading_optimisation.gd", "game/tests/profile_race_loading_optimisation.gd",
         "game/tests/test_race_loading_first_lap.gd", "game/tests/review_loading_template_sources.gd",
         *[prefix + name for name in ("run_check.py", "summarize.py", "checkpoint.py", "selection_control.gd",
                                      "world_cloud_control.gd", "reuse_control.gd")],
         *[prefix + "before/" + name for name in ("game/editor/editor_memory.gd",
                                                 "game/vehicle/effect_render_preparation.gd",
                                                 "game/track/prepared_world_cache.gd",
                                                 "game/race/selected_track_preparation.gd")]]
def normalized(path):
    return path.read_bytes().replace(b"\r\n", b"\n")

# Rebase only the owned hunks onto today's concurrent App/tracker contents.
app_lines = normalized(root / "game/core/app.gd").decode("utf-8").splitlines(keepends=True)
indices = [i for i, s in enumerate(app_lines) if s.lstrip().startswith("var layout_ready: bool = SELECTED_PREPARATION.ready_for_job()")]
assert len(indices) == 1
at = indices[0]
assert app_lines[at + 1].rstrip().endswith("and layout_ready:")
app_lines[at + 1] = app_lines[at + 1].replace(" and layout_ready:", ":")
del app_lines[at]
(base / "game/core/app.gd").write_text("".join(app_lines), encoding="utf-8", newline="")
marker = "<!-- RACE-LOADING-IMPLEMENTATION-20261102 -->"
end_marker = "<!-- /RACE-LOADING-IMPLEMENTATION-20261102 -->"
for name in ("AGENTS.md", "DEVELOPMENT_STATUS.md"):
    current = normalized(root / name).decode("utf-8")
    assert current.count(marker) == 1 and current.count(end_marker) == 1
    start, end = current.index(marker), current.index(end_marker) + len(end_marker)
    if current[end:].startswith("\n\n"):
        end += 2
    (base / name).write_text(current[:start] + current[end:], encoding="utf-8", newline="")

before, after, patch_parts = {}, {}, []
for path in changed + added:
    old = normalized(base / path) if path in changed else b""
    new = normalized(root / path)
    before[path], after[path] = old, new
    patch_parts.append("diff --git a/" + path + " b/" + path + "\n")
    if path in added:
        patch_parts.append("new file mode 100644\n")
    patch_parts.extend(difflib.unified_diff(old.decode("utf-8").splitlines(keepends=True),
                                          new.decode("utf-8").splitlines(keepends=True),
                                          fromfile="a/" + path if path in changed else "/dev/null", tofile="b/" + path))
patch = evidence / "task.patch"
patch.write_bytes("".join(patch_parts).encode("utf-8"))
owned = root / "build/race-loading-implementation-20261102" / ("checkpoint-" + str(time.time_ns()))
owned.mkdir(parents=True)
assert owned.resolve().is_relative_to((root / "build/race-loading-implementation-20261102").resolve())
for path in changed:
    target = owned / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(before[path])
commands = []
def apply(*arguments):
    command = ["git", "apply", "--directory=" + owned.relative_to(root).as_posix(), *arguments, str(patch)]
    result = subprocess.run(command, cwd=root, capture_output=True, text=True)
    commands.append(dict(command=command, exit_code=result.returncode, output=result.stdout + result.stderr))
    assert result.returncode == 0, result.stderr

apply("--check")
apply()
assert all(normalized(owned / p) == after[p] for p in changed + added)
apply("--reverse", "--check")
apply("--reverse")
assert all(normalized(owned / p) == before[p] for p in changed)
assert all(not (owned / p).exists() for p in added)
report = dict(files=changed + added, forward_content_exact=True, reverse_content_exact=True,
              concurrent_app_tracker_hunks_excluded=True, main_index_written=False,
              patch_sha256=hashlib.sha256(patch.read_bytes()).hexdigest(), commands=commands,
              source_sha256={p: hashlib.sha256(after[p]).hexdigest() for p in after})
(evidence / "checkpoint.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("Task-only patch: forward/reverse/content checks passed; concurrent App/tracker changes excluded.")
