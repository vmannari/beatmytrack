"""Build a task-only patch against saved pre-task work, preserving other edits."""
import difflib
import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
EVIDENCE = Path(__file__).resolve().parent
EXISTING = ["game/backend/weekly_rivalry_client.gd", "backend/bmt_backend/rivalry.py",
    "DEVELOPMENT_STATUS.md", "docs/PHASE_0_PLAN.md"]
ADDED = ["game/tests/test_rivalry_week_completion.gd", "backend/tests/test_rivalry_week_completion.py",
    "scripts/test_rivalry_week_postgres.py", "docs/RIVALRY_WEEK_COMPLETION.md"]


def main():
    chunks = []
    manifest = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "files": {}}
    for filename in EXISTING + ADDED:
        old = (EVIDENCE / "before" / filename.replace("/", "__")).read_bytes() if filename in EXISTING else b""
        new = (ROOT / filename).read_bytes()
        before = old.decode("utf-8").replace("\r\n", "\n")
        after = new.decode("utf-8").replace("\r\n", "\n")
        if before == after:
            continue
        header = f"diff --git a/{filename} b/{filename}\n"
        if filename in ADDED:
            header += "new file mode 100644\n"
        chunks.append(header + "".join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
            fromfile="a/" + filename if old else "/dev/null", tofile="b/" + filename)))
        manifest["files"][filename] = {"before_sha256": hashlib.sha256(old).hexdigest(),
            "after_sha256": hashlib.sha256(new).hexdigest()}
    (EVIDENCE / "scoped-change.patch").write_text("".join(chunks), encoding="utf-8", newline="\n")
    (EVIDENCE / "checkpoint.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Task-only checkpoint: {len(manifest['files'])} files")


if __name__ == "__main__":
    main()
