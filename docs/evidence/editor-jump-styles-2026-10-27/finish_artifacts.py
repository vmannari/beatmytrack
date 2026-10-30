"""Build a source-only review patch against task-start files, excluding concurrent App edits."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
BEFORE = OUT / "before"
existing = sorted(path.relative_to(BEFORE).as_posix() for path in BEFORE.rglob("*") if path.is_file())
added = ["game/editor/jump_profiles.gd", "game/editor/jump_style_picker.gd",
         "game/track/jump_visual.gd", "game/track/jump_earth.gdshader",
         "game/tests/test_editor_jump_styles.gd", "game/tests/test_jump_profiles_worker.gd",
         "game/tests/fixtures/jump_styles_before/track_hazards.gd.txt",
         "game/tests/fixtures/jump_styles_before/hazard_visual.gd.txt",
         "game/tests/fixtures/jump_styles_before/README.md"]
for name in list(added):
    if (ROOT / (name + ".uid")).is_file(): added.append(name + ".uid")
parts = []
hashes = {}
excluded = []
validation = ROOT / "tmp/jump-styles-checkpoint-validation"
validation.mkdir(parents=True, exist_ok=True)
subprocess.run(["git", "init", "--quiet", str(validation)], check=True, cwd=ROOT)
for name in existing + added:
    old = (BEFORE / name).read_text(encoding="utf-8") if name in existing else ""
    current = (ROOT / name).read_text(encoding="utf-8")
    scoped = current
    if name == "game/core/app.gd":
        a = old.splitlines(keepends=True)
        b = current.splitlines(keepends=True)
        own = a.copy()
        for tag, first, end, new_first, new_end in reversed(difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes()):
            if tag == "equal": continue
            changed = "".join(a[first:end] + b[new_first:new_end])
            if "jump_profile" in changed or "jump_style_picker" in changed:
                own[first:end] = b[new_first:new_end]
            else:
                excluded.append({"file": name, "baseline_lines": [first + 1, end], "reason": "Concurrent account-layout or road-material work"})
        scoped = "".join(own)
    if old == scoped: continue
    parts.extend(difflib.unified_diff(old.splitlines(keepends=True), scoped.splitlines(keepends=True),
                                    fromfile="a/" + name if name in existing else "/dev/null", tofile="b/" + name))
    if name in existing:
        target = validation / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(old, encoding="utf-8", newline="\n")
    hashes[name] = {"actual_sha256": hashlib.sha256((ROOT / name).read_bytes()).hexdigest(),
                    "scope_lf_sha256": hashlib.sha256(scoped.encode()).hexdigest(),
                    "before_sha256": hashlib.sha256((BEFORE / name).read_bytes()).hexdigest() if name in existing else None}
patch = OUT / "task.patch"
patch.write_text("".join(parts), encoding="utf-8", newline="\n")
checked = subprocess.run(["git", "-C", str(validation), "apply", "--check", str(patch)], capture_output=True, text=True)
(OUT / "patch-check.log").write_text(checked.stdout + checked.stderr + f"\nexit={checked.returncode}\n", encoding="utf-8")
if checked.returncode: raise RuntimeError(checked.stderr)
commands = {}
for file in sorted(OUT.glob("commands-*.json")):
    commands[file.stem.removeprefix("commands-")] = json.loads(file.read_text())
results = {file.stem: json.loads(file.read_text()) for file in OUT.glob("results-*.json")}
report = {"requirements": {"EJS01": "Restrained geometry and short hops", "EJS02": "Five styles including natural Desert bumps", "EJS03": "Exact historical contracts and data-only worker packaging", "EJS04": "Palette, direct selection, copy, undo and local persistence", "Q01": "Native views, actual checks and review patch"},
          "source_files": hashes, "excluded_concurrent_changes": excluded, "commands": commands, "results": results,
          "patch_check": {"exit": checked.returncode, "patch_sha256": hashlib.sha256(patch.read_bytes()).hexdigest()},
          "known_findings": ["Five speed-bump-width failures reproduce with task-start edited sources in an isolated project", "Existing sandbox certificate-store error remains in raw engine logs", "Initial test harness path, CRLF and StringName mistakes are retained in initial logs", "Initial reversed deck normals caused Desert striping; corrected winding and upward-normal assertions pass", "Concurrent sign-in SVG/LinkButton import errors occurred in an intermediate run; final runs are checked separately", "First worker import could not save editor settings outside the workspace; staged execution uses an isolated APPDATA root"],
          "remaining_acceptance": ["Reload/rebuild current client", "Owner driving feel and visual acceptance", "Matching backend rollout before publishing documents containing the new profiles", "Physical-device appearance, motion, touch and performance"],
          "device_test_performed": False, "device_attachment_query_performed": False, "cloud_mutation": False,
          "owner_save_mutation": False, "root_index_staging_commit_merge": False}
(OUT / "report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(f"Review patch: {len(hashes)} files; git apply --check passed; {len(excluded)} concurrent App changes excluded")
