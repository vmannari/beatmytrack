"""Retain task-original bytes and build a task-only patch in this shared tree."""
import ast
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
FILES = [
    "backend/bmt_backend/rivalry.py", "backend/bmt_backend/rivalry_models.py",
    "backend/bmt_backend/achievement_models.py", "backend/bmt_backend/achievements.py",
    "backend/bmt_backend/creator_achievements.py",
    "backend/bmt_backend/news.py", "backend/bmt_backend/privacy.py", "backend/bmt_backend/worker.py",
    "backend/tests/test_achievements.py", "backend/README.md",
    "backend/bmt_backend/migrations/versions/0054_priority_scaling.py",
    "backend/tests/test_priority_scaling.py",
]
BUILD = ROOT / "build/backend-priority-fixes-2026-10-23/original"
if sys.argv[1] == "capture":
    BUILD.mkdir(parents=True, exist_ok=False)
    manifest = {}
    for name in FILES:
        path = ROOT / name
        manifest[name] = hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
        if path.exists():
            dest = BUILD / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(path.read_bytes())
    (HERE / "original.json").write_text(json.dumps(manifest, indent=2) + "\n")
else:
    manifest = json.loads((HERE / "original.json").read_text())
    patch = []
    hashes = {}
    for name in FILES:
        original = BUILD / name
        current = ROOT / name
        hashes[name] = hashlib.sha256(current.read_bytes()).hexdigest() if current.exists() else None
        reviewed = current
        if name == "backend/bmt_backend/rivalry.py":
            # A concurrent task changed skill_score/imports after our capture.
            # Rebuild this task's patch from the original with only owned join
            # functions and literal-column import; never attribute its work here.
            old, new = original.read_text(), current.read_text()
            old_tree, new_tree = ast.parse(old), ast.parse(new)
            owned = {node.name: ast.get_source_segment(new, node) for node in new_tree.body
                     if isinstance(node, ast.FunctionDef) and node.name in
                     ("join", "open_group_candidates", "reserve_open_group")}
            old_join = next(node for node in old_tree.body if isinstance(node, ast.FunctionDef) and node.name == "join")
            old = old.replace(ast.get_source_segment(old, old_join), "\n\n\n".join(
                owned[key] for key in ("join", "open_group_candidates", "reserve_open_group")), 1)
            old = old.replace("from sqlalchemy import case, func, or_, select, update",
                              "from sqlalchemy import case, func, literal_column, or_, select, update", 1)
            reviewed = ROOT / "build/backend-priority-fixes-2026-10-23/task-final" / name
            reviewed.parent.mkdir(parents=True, exist_ok=True)
            reviewed.write_text(old)
        result = subprocess.run(["git", "diff", "--no-index", "--", str(original) if original.exists() else "/dev/null",
                                 str(reviewed)], capture_output=True, check=False)
        if result.returncode not in (0, 1):
            raise RuntimeError(result.stderr.decode())
        lines = []
        for line in result.stdout.decode().splitlines():
            if line.startswith("diff --git "):
                line = f"diff --git a/{name} b/{name}"
            elif line.startswith("--- "):
                line = f"--- a/{name}" if original.exists() else "--- /dev/null"
            elif line.startswith("+++ "):
                line = f"+++ b/{name}"
            lines.append(line)
        patch.append("\n".join(lines) + "\n" if lines else "")
    (HERE / "task-only.patch").write_bytes("".join(patch).encode("utf-8"))
    (HERE / "final-source-hashes.json").write_text(json.dumps(hashes, indent=2) + "\n")
