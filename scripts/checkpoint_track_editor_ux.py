"""UX08: exact, reversible source checkpoint in a private Git repository.

The shared index, concurrent App header work and surrounding project history
are preserved. Run after validation/documentation, from the repository root.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / ".tmp/track-editor-ux-20261116"
OUT = ROOT / "docs/evidence/track-editor-ux-2026-11-16"
MARKER = "TRACK-EDITOR-UX-20261116"
digest = lambda data: hashlib.sha256(data).hexdigest()
modified = {
    "game/core/features/editor.gd": "editor.gd",
    "game/editor/editor_canvas.gd": "editor_canvas.gd",
    "game/editor/editor_style.gd": "editor_style.gd",
    "game/tests/test_editor_workflow.gd": "test_editor_workflow.gd",
    "game/tests/test_surface_modes.gd": "test_surface_modes.gd",
}
before = {name: (WORK / "before" / saved).read_bytes() for name, saved in modified.items()}
for path in (WORK / "before/localization").glob("*.po"):
    name = "game/localization/" + path.name
    before[name] = path.read_bytes()
    assert (ROOT / name).read_bytes().startswith(before[name]), name

# Surround the one editor-specific App line with CURRENT concurrent changes.
app_name = "game/core/app.gd"
app_after = (ROOT / app_name).read_bytes()
original_app = (WORK / "before/app.gd").read_bytes()
old_line = next(line for line in original_app.splitlines(keepends=True) if b'editor_view = {"zoom":' in line)
new_line = next(line for line in app_after.splitlines(keepends=True) if b'editor_view = preload("res://editor/view_state.gd")' in line)
before[app_name] = app_after.replace(new_line, old_line)

for name in ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]:
    data = (ROOT / name).read_bytes()
    pattern = (r"<!-- " + MARKER + r" -->\r?\n.*?<!-- /" + MARKER + r" -->\r?\n(?:\r?\n)?").encode()
    before[name], count = re.subn(pattern, b"", data, flags=re.S)
    assert count == 1, name

added = [
    "docs/track_editor_ux_plan.md",
    "game/editor/view_state.gd",
    "game/tests/test_editor_ux_2026_11_16.gd",
    "scripts/translations/track_editor_ux_2026_11_16.tsv",
    "scripts/checkpoint_track_editor_ux.py",
]
for name in ["game/editor/view_state.gd.uid", "game/tests/test_editor_ux_2026_11_16.gd.uid"]:
    if (ROOT / name).exists(): added.append(name)
after = {name: (ROOT / name).read_bytes() for name in sorted(set(before) | set(added))}
private = (WORK / "source-checkpoint").resolve()
assert private.is_relative_to(WORK.resolve()) and not private.exists()
private.mkdir(parents=True)
index = digest((ROOT / ".git/index").read_bytes())

def git(*args):
    result = subprocess.run(["git", "-c", "core.autocrlf=false", "-c", "core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol", *args], cwd=private, capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    return result.stdout

def write(files):
    for name, data in files.items():
        target = private / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)

git("init", "--quiet")
git("config", "user.name", "Local source checkpoint")
git("config", "user.email", "checkpoint@invalid.local")
write(before)
git("add", "--all")
git("commit", "--quiet", "-m", "Editor UX task-start sources with current concurrent App context")
write(after)
git("add", "--all")
patch = git("diff", "--cached", "--binary", "--full-index", "HEAD")
(OUT / "source.patch").write_bytes(patch)
git("apply", "--check", "--reverse", str(OUT / "source.patch"))
git("apply", "--reverse", "--whitespace=error", str(OUT / "source.patch"))
for name in after:
    target = private / name
    assert target.read_bytes() == before[name] if name in before else not target.exists(), name
git("apply", "--whitespace=error", str(OUT / "source.patch"))
for name, data in after.items(): assert (private / name).read_bytes() == data, name
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "UX01-UX08 safe track-editor interactions and visible state")
assert digest((ROOT / ".git/index").read_bytes()) == index
receipt = {
    "source_files": len(after), "forward_byte_exact": True, "reverse_byte_exact": True,
    "main_index_unchanged_during_checkpoint": True, "private_commit": git("rev-parse", "HEAD").decode().strip(),
    "patch_sha256": digest(patch),
    "scope": "Editor source, authored copy, regression fixtures and marked documentation only. Concurrent App header changes are identical on both sides. No generated build identity, project setting, vehicle, cloud data or native image is part of the reversible source patch.",
    "files": {name: {"before_sha256": digest(before[name]) if name in before else None, "sha256": digest(data)} for name, data in after.items()},
}
(OUT / "source-checkpoint.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: value for key, value in receipt.items() if key != "files"}, indent=2))
