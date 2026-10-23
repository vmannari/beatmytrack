"""Create a scoped, reversible source checkpoint without modifying root Git."""
import hashlib
import json
import re
import shutil
import subprocess
from pathlib import Path

root = next(p for p in Path(__file__).resolve().parents if (p / "game/core/app.gd").is_file())
task = root / "docs/evidence/publication-confirmation-2026-10-19"
before = task / "before"
repo = root / "build/publication-confirmation-2026-10-19/checkpoint"
changed = ["game/core/app.gd", "game/ui/community_safety_ui.gd", "game/tests/test_publication_notice.gd",
           "game/tests/test_publication_notifications.gd", "game/tests/test_publishing_slots.gd",
           "AGENTS.md", "DEVELOPMENT_STATUS.md"]
added = ["game/ui/publication_dialog.gd", "game/ui/publication_dialog.gd.uid",
         "game/tests/test_publication_confirmation.gd", "game/tests/test_publication_confirmation.gd.uid",
         "docs/PUBLICATION_CONFIRMATION_2026_10_19.md"]
for name, pattern in [("AGENTS.md", r"(?m)^## Publication confirmation and bounded wait override[^\n]*\n[^\n]*\n\n"),
                      ("DEVELOPMENT_STATUS.md", r"(?m)^2026-10-19 PCF01-PCF03/G01/R01/Q01:[^\n]*\n\n")]:
    content = (root / name).read_text(encoding="utf-8")
    content, count = re.subn(pattern, "", content, count=1)
    assert count == 1
    initial = before / (name + ".initial")
    if not initial.exists(): shutil.copyfile(before / name, initial)
    (before / name).write_text(content, encoding="utf-8", newline="\n")
assert not repo.exists()
repo.mkdir(parents=True)


def git(*args):
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, check=True)
    return result.stdout


def copy(source, relative):
    target = repo / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(source.read_text(encoding="utf-8"), encoding="utf-8", newline="\n")


git("init", "--quiet")
git("config", "user.name", "Codex task checkpoint")
git("config", "user.email", "codex@localhost")
git("config", "core.autocrlf", "false")
for relative in changed:
    copy(before / relative.replace("/", "__"), relative)
git("add", "--all")
git("commit", "--quiet", "-m", "Preserve original publication callback and fixtures")
base = git("rev-parse", "HEAD").decode().strip()
for relative in changed + added: copy(root / relative, relative)
git("add", "--all")
git("diff", "--cached", "--check")
(task / "task-only.patch").write_bytes(git("diff", "--cached", "--binary", "--full-index"))
git("commit", "--quiet", "-m", "Confirm publication and retain its bounded animated wait")
git("apply", "--reverse", "--check", str(task / "task-only.patch"))
receipt = {"base": base, "head": git("rev-parse", "HEAD").decode().strip(),
           "files": {f: hashlib.sha256((root / f).read_bytes()).hexdigest() for f in changed + added},
           "checks": ["staged whitespace", "reverse patch application"], "root_git_metadata_changed": False}
(task / "checkpoint.json").write_text(json.dumps(receipt, indent=2))
print(receipt["head"])
