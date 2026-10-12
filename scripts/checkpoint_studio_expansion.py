"""Save this task's incremental changes against its dirty-workspace before files."""
import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BEFORE = ROOT / "build/studio-expansion-2026-10-11/before"
OUTPUT = ROOT / "docs/evidence/studio-expansion-2026-10-11"
NEW = [
    "backend/bmt_backend/studio_cases.py", "backend/bmt_backend/studio_case_models.py",
    "backend/bmt_backend/studio_competitions.py", "backend/bmt_backend/quality.py",
    "backend/bmt_backend/quality_models.py", "backend/bmt_backend/provider_proofs.py",
    "backend/bmt_backend/migrations/versions/0026_studio_cases.py",
    "backend/bmt_backend/migrations/versions/0027_client_quality.py",
    "backend/bmt_backend/admin_ui/operations.js", "backend/tests/test_studio_operations.py",
    "backend/tests/test_studio_moderation.py", "backend/tests/test_studio_expansion_postgres.py",
    "backend/tests/test_client_quality.py", "backend/tests/test_provider_proofs.py",
    "game/backend/client_quality.gd", "game/backend/client_quality.gd.uid",
    "game/tests/test_client_quality.gd", "game/tests/test_client_quality.gd.uid",
    "native/google_sign_in/src/org/beatmytrack/signin/BmtProcessExits.java",
    "scripts/test_studio_expansion_console.py", "scripts/test_studio_expansion_postgres.py",
    "scripts/checkpoint_studio_expansion.py", "docs/STUDIO_EXPANSION_2026_10_11.md",
]


def main():
    sources = {file.name.replace("__", "/"): file for file in BEFORE.iterdir() if file.is_file()}
    for name in NEW:
        if name in sources:
            raise RuntimeError("Duplicate checkpoint path")
        sources[name] = None
    manifest, patches = [], []
    for name, original in sorted(sources.items()):
        current = ROOT / name
        before = original.read_bytes() if original else b""
        after = current.read_bytes()
        if before == after:
            continue
        manifest.append({"path": name, "before_sha256": hashlib.sha256(before).hexdigest() if original else None,
            "after_sha256": hashlib.sha256(after).hexdigest(), "bytes": len(after)})
        patches.extend(difflib.unified_diff(before.decode("utf-8").splitlines(keepends=True),
            after.decode("utf-8").splitlines(keepends=True),
            fromfile="a/" + name if original else "/dev/null", tofile="b/" + name))
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / "workspace-task-only.patch").write_text("".join(patches), encoding="utf-8")
    (OUTPUT / "checkpoint.json").write_text(json.dumps({"schema": "bmt-workspace-checkpoint-v1",
        "baseline": "Saved dirty-workspace files; not clean Git HEAD", "git_commit_created": False,
        "deployment_performed": False, "files": manifest}, indent=2) + "\n", encoding="utf-8")
    print(f"Scoped checkpoint: {len(manifest)} source/docs files; no private configuration or unrelated changes")


if __name__ == "__main__":
    main()
