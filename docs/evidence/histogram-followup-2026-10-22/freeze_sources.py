"""Freeze a hash-verified backend so concurrent tasks cannot mix test sources."""
import hashlib
import json
import shutil
from pathlib import Path

root = next(parent for parent in Path(__file__).resolve().parents if (parent / "backend/bmt_backend").is_dir())
target = root / "build/histogram-followup-2026-10-22-verified/backend"
target.mkdir(parents=True, exist_ok=True)
files = [path for path in (root / "backend").rglob("*") if path.is_file()
         and not any(part in ("__pycache__", ".pytest_cache", ".ruff_cache") for part in path.parts)
         and path.suffix != ".pyc"]
hashes = {}
for path in files:
    relative = path.relative_to(root / "backend")
    output = target / relative
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, output)
    hashes[str(relative)] = hashlib.sha256(output.read_bytes()).hexdigest()
assert all(hashlib.sha256(path.read_bytes()).hexdigest() == hashes[str(path.relative_to(root / "backend"))] for path in files), "Source changed during freeze; retry"
(Path(__file__).parent / "frozen-source.json").write_text(json.dumps(hashes, indent=2))
print(json.dumps({"frozen_backend":str(target), "files":len(files)}))
