"""Create and check a task-only patch against exact starting sources."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

root = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent
paths = [
    "game/ui/store_page.gd",
    "game/backend/store_access_cache.gd",
    "game/tests/test_store_first_entry.gd",
    "docs/STORE_FIRST_ENTRY_2026_10_28.md",
]
validation = root / "build/store-first-entry-2026-10-28-checkpoint"
patch = []
hashes = {}
for name in paths:
    before = evidence / "before" / name
    current = root / name
    old = before.read_text(encoding="utf-8-sig") if before.exists() else ""
    new = current.read_text(encoding="utf-8-sig")
    patch.append(f"diff --git a/{name} b/{name}\n")
    if not before.exists(): patch.append("new file mode 100644\n")
    patch.extend(difflib.unified_diff(old.splitlines(True), new.splitlines(True),
                                    fromfile=f"a/{name}" if before.exists() else "/dev/null",
                                    tofile=f"b/{name}"))
    target = validation / name
    target.parent.mkdir(parents=True, exist_ok=True)
    if before.exists():
        target.write_text(old, encoding="utf-8", newline="\n")
    elif target.exists():
        raise RuntimeError(f"Use a fresh validation directory: {target}")
    hashes[name] = {
        "before_sha256": hashlib.sha256(before.read_bytes()).hexdigest() if before.exists() else None,
        "after_sha256": hashlib.sha256(current.read_bytes()).hexdigest(),
    }
patch_path = evidence / "task.patch"
patch_path.write_text("".join(patch), encoding="utf-8", newline="\n")
directory = "--directory=" + validation.relative_to(root).as_posix()
commands = []
for mode in ["--check", "--apply"]:
    args = ["git", "apply", directory]
    if mode == "--check": args.append(mode)
    args.append(str(patch_path.relative_to(root)))
    result = subprocess.run(args, cwd=root, capture_output=True, text=True)
    commands.append({"args": args, "exit_code": result.returncode,
                     "stdout": result.stdout, "stderr": result.stderr})
    if result.returncode:
        (evidence / "checkpoint-failure.json").write_text(json.dumps(commands, indent=2)+"\n", encoding="utf-8")
        raise RuntimeError(result.stderr)
for name in paths:
    assert (validation / name).read_text(encoding="utf-8") == (root / name).read_text(encoding="utf-8-sig")
    hashes[name]["applied_sha256"] = hashlib.sha256((validation / name).read_bytes()).hexdigest()
(evidence / "checkpoint.json").write_text(json.dumps({"paths": hashes,
    "commands": commands, "applied_text_matches": True,
    "main_index_used": False}, indent=2)+"\n", encoding="utf-8")
print("CHECKPOINT: 4 scoped files; git check/apply pass; applied text matches")
