"""Byte-exact private checkpoint for EF01-EF04; never stage the shared index."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / ".tmp/editor-finish-20261117"
OUT = ROOT / "docs/evidence/editor-finish-2026-11-17"
MARKER = "EDITOR-FINISH-20261117"
TRACKERS = ["AGENTS.md", "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md", "docs/track_editor_ux_plan.md"]
digest = lambda data: hashlib.sha256(data).hexdigest()
before, after = {}, {}
for original in (WORK / "before").rglob("*"):
    if not original.is_file():
        continue
    name = original.relative_to(WORK / "before").as_posix()
    if name in TRACKERS:
        continue
    data = (ROOT / name).read_bytes()
    if data == original.read_bytes():
        continue
    before[name], after[name] = original.read_bytes(), data
for name in TRACKERS:
    after[name] = (ROOT / name).read_bytes()
    pattern = (r"<!-- " + MARKER + r" -->\r?\n.*?<!-- /" + MARKER + r" -->\r?\n(?:\r?\n)?").encode()
    before[name], count = re.subn(pattern, b"", after[name], flags=re.S)
    assert count == 1, name
for name in ["game/tests/test_editor_finish_2026_11_17.gd", "docs/EDITOR_FINISH_2026_11_17.md", "scripts/checkpoint_editor_finish.py"]:
    after[name] = (ROOT / name).read_bytes()
uid = "game/tests/test_editor_finish_2026_11_17.gd.uid"
if (ROOT / uid).exists():
    after[uid] = (ROOT / uid).read_bytes()

private = (WORK / "source-checkpoint-delivery").resolve()
assert private.is_relative_to(WORK.resolve()) and not private.exists()
private.mkdir(parents=True)
index = digest((ROOT / ".git/index").read_bytes())

def git(*args):
    result = subprocess.run(["git", "-c", "core.autocrlf=false", "-c", "core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol", *args], cwd=private, capture_output=True)
    assert result.returncode == 0, result.stderr.decode(errors="replace")
    return result.stdout

def write(files):
    for name, data in files.items():
        path = private / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

git("init", "--quiet")
git("config", "user.name", "Local source checkpoint")
git("config", "user.email", "checkpoint@invalid.local")
write(before)
git("add", "--all")
git("commit", "--quiet", "-m", "Editor before owner-requested cards, centring and complete editor-menu visibility")
write(after)
git("add", "--all")
patch = git("diff", "--cached", "--binary", "--full-index", "HEAD")
(OUT / "source.patch").write_bytes(patch)
git("apply", "--check", "--reverse", str(OUT / "source.patch"))
git("apply", "--reverse", "--whitespace=error", str(OUT / "source.patch"))
for name in after:
    path = private / name
    assert path.read_bytes() == before[name] if name in before else not path.exists(), name
git("apply", "--whitespace=error", str(OUT / "source.patch"))
for name, data in after.items():
    assert (private / name).read_bytes() == data, name
git("diff", "--cached", "--check")
git("commit", "--quiet", "-m", "EF01-EF04 shared card styling, centred tools and readable bounded menus")
assert digest((ROOT / ".git/index").read_bytes()) == index
receipt = {
    "files": {name: {"before_sha256": digest(before[name]) if name in before else None, "sha256": digest(data)} for name, data in sorted(after.items())},
    "forward_byte_exact": True, "reverse_byte_exact": True,
    "shared_index_unchanged_during_checkpoint": True,
    "private_commit": git("rev-parse", "HEAD").decode().strip(), "patch_sha256": digest(patch),
    "scope": "EF01-EF04 shared card presentation, native captions, bounded menu/file-dialog layout and native fixtures. Preceding editor interactions, vehicle work and shared index preserved."
}
(OUT / "source-checkpoint.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
print(json.dumps({key: value for key, value in receipt.items() if key != "files"}, indent=2))
