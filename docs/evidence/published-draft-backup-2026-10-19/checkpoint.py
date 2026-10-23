"""Task-only source checkpoint; root Git metadata and owner files stay untouched."""
import hashlib
import json
import subprocess
from pathlib import Path

root = next(p for p in Path(__file__).resolve().parents if (p / "game/persistence/track_library.gd").is_file())
evidence = root / "docs/evidence/published-draft-backup-2026-10-19"
checkpoint = root / "build/published-draft-backup-2026-10-19/checkpoint-scoped"
changed = {"game/persistence/track_library.gd": "track_library.gd.txt", "AGENTS.md": "AGENTS.md",
           "DEVELOPMENT_STATUS.md": "DEVELOPMENT_STATUS.md"}
added = ["game/tests/test_published_draft_backup.gd", "game/tests/test_published_draft_backup.gd.uid",
         "docs/PUBLISHED_DRAFT_BACKUP_2026_10_19.md"]
assert not checkpoint.exists()
checkpoint.mkdir(parents=True)


def git(*args):
    result = subprocess.run(["git", "-C", str(checkpoint), *args], capture_output=True, check=True)
    return result.stdout


def copy(source, relative):
    destination = checkpoint / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(source.read_text(encoding="utf-8"), encoding="utf-8", newline="\n")


git("init", "--quiet")
git("config", "user.name", "Codex task checkpoint")
git("config", "user.email", "codex@localhost")
git("config", "core.autocrlf", "false")
for relative, before in changed.items():
    copy(evidence / "before" / before, relative)
git("add", "--all")
git("commit", "--quiet", "-m", "Preserve original publication draft recovery")
base = git("rev-parse", "HEAD").decode().strip()
for relative in list(changed) + added:
    copy(root / relative, relative)
git("add", "--all")
git("diff", "--cached", "--check")
(evidence / "task-only.patch").write_bytes(git("diff", "--cached", "--binary", "--full-index"))
git("commit", "--quiet", "-m", "Keep retired publication backups out of draft lists")
git("apply", "--reverse", "--check", str(evidence / "task-only.patch"))
receipt = {"base": base, "head": git("rev-parse", "HEAD").decode().strip(),
           "files": {p: hashlib.sha256((root / p).read_bytes()).hexdigest() for p in list(changed) + added},
           "checks": ["staged whitespace", "reverse patch application"], "root_git_metadata_changed": False}
(evidence / "checkpoint.json").write_text(json.dumps(receipt, indent=2))
print(receipt["head"])
