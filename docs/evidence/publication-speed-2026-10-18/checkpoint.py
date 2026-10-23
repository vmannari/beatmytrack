"""Create a task-only Git checkpoint without changing root Git metadata."""
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = next(parent for parent in Path(__file__).resolve().parents if (parent / "backend/bmt_backend").is_dir())
TASK = ROOT / "docs/evidence/publication-speed-2026-10-18"
CHECKPOINT = ROOT / "build/publication-speed-2026-10-18/checkpoint-lf"
BEFORE = TASK / "before"
changed = ["backend/bmt_backend/publications.py", "backend/bmt_backend/service_worker.py",
    "backend/bmt_backend/worker_lifecycle.py", "backend/deploy/stage_verifier.py",
    "backend/deploy/gcp/staging.py", "backend/deploy/compose.yaml", "backend/deploy/compose.pc.yaml",
    "backend/tests/service_worker_probe.py", "backend/tests/test_service_worker.py", "AGENTS.md", "DEVELOPMENT_STATUS.md"]
added = ["backend/bmt_backend/publication_worker.py", "backend/tests/test_publication_latency.py",
    "backend/tests/publication_latency_probe.py", "docs/PUBLICATION_SPEED_2026_10_18.md"]

for relative, old, new in [
    ("backend/deploy/stage_verifier.py", '        "geometry_acceleration",\n', ""),
    ("backend/deploy/gcp/staging.py", "--args=-m,bmt_backend.service_worker", "--args=-m,bmt_backend.worker")]:
    target = BEFORE / relative.replace("/", "__")
    if not target.exists():
        source = (ROOT / relative).read_text(encoding="utf-8")
        assert source.count(old) == 1
        target.write_text(source.replace(old, new, 1), encoding="utf-8")

assert not CHECKPOINT.exists(), "Never overwrite an existing checkpoint"
CHECKPOINT.mkdir(parents=True)


def git(*args):
    return subprocess.run(["git", "-C", str(CHECKPOINT), *args], check=True, capture_output=True).stdout


git("init", "--quiet")
git("config", "user.name", "Codex task checkpoint")
git("config", "user.email", "codex@localhost")
git("config", "core.autocrlf", "false")
for relative in changed:
    target = CHECKPOINT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text((BEFORE / relative.replace("/", "__")).read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
git("add", "--all")
git("commit", "--quiet", "-m", "Preserve pre-task publication sources")
base = git("rev-parse", "HEAD").decode().strip()
for relative in changed + added:
    target = CHECKPOINT / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text((ROOT / relative).read_text(encoding="utf-8"), encoding="utf-8", newline="\n")
git("add", "--all")
git("diff", "--cached", "--check")
(TASK / "task-only.patch").write_bytes(git("diff", "--cached", "--binary", "--full-index"))
git("commit", "--quiet", "-m", "Verify publications independently of busy competition work")
head = git("rev-parse", "HEAD").decode().strip()
git("apply", "--reverse", "--check", str(TASK / "task-only.patch"))
receipt = {"base": base, "head": head, "files": {relative: hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
    for relative in changed + added}, "root_git_metadata_changed": False,
    "checks": ["staged diff whitespace", "reverse patch application"]}
(TASK / "checkpoint.json").write_text(json.dumps(receipt, indent=2))
print(json.dumps({"base": base, "head": head, "files": len(changed + added)}))
