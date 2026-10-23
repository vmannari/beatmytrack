"""Count actual directory advances in saved original and final pagination.

Synthetic directory entries, actual manifest files/seeks. No deployed storage,
database, service, device or network is used. This is not a NAS timing claim.
"""
import ast
import json
import os
import re
import sys
import tempfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "backend/tests"))
from bmt_backend.local_object_listing import (
    HEADER,
    SCAN_DIRECTORY,
    TEMPORARY_NAME,
)
from bmt_backend.storage import LocalBlobStore
from test_local_object_listing import directory_work


def main():
    source = Path(__file__).with_name("before") / "storage.py"
    cls = next(node for node in ast.parse(source.read_text(encoding="utf-8")).body
               if isinstance(node, ast.ClassDef) and node.name == "LocalBlobStore")
    method = next(node for node in cls.body if isinstance(node, ast.FunctionDef) and node.name == "list_objects")
    scope = {"os": os, "re": re, "TEMPORARY_NAME": TEMPORARY_NAME}
    exec(compile(ast.Module(body=[method], type_ignores=[]), str(source), "exec"), scope)  # noqa: S102
    base = ROOT / "build/local-object-pagination-2026-10-22"
    base.mkdir(parents=True, exist_ok=True)
    result = {"scope": __doc__, "page_size": 1000, "measurements": []}
    with tempfile.TemporaryDirectory(prefix="pagination-benchmark-", dir=base) as temporary:
        directory = Path(temporary).resolve()
        assert directory.is_relative_to(base.resolve())
        for size in (1000, 10000, 100000):
            with pytest.MonkeyPatch.context() as patch:
                old = directory_work(directory / f"before-{size}", size, patch, scope["list_objects"])
                new_root = directory / f"after-{size}"
                new = directory_work(new_root, size, patch, LocalBlobStore.list_objects)
            manifest = next((new_root / SCAN_DIRECTORY).glob("*.scan"))
            row = {"objects": size, "before_directory_advances": old, "after_directory_advances": new,
                   "manifest_bytes": manifest.stat().st_size}
            assert new == size and row["manifest_bytes"] == len(HEADER) + size * 73
            result["measurements"].append(row)
            print(json.dumps(row), flush=True)
    Path(__file__).with_name("benchmark-results.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
