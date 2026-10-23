"""Measure local-listing IO requests with synthetic entries and real manifests.

This counts application metadata requests and raw manifest writes. DirEntry type
checks can be cached by an actual filesystem; these are not universal syscall or
NAS throughput measurements. No live storage/database/service is accessed.
"""
import ast
import importlib.util
import io
import json
import logging
import os
import stat
import sys
import tempfile
import time
from pathlib import Path
from types import SimpleNamespace

import pytest
from bmt_backend import local_object_listing as current
from bmt_backend.storage import LocalBlobStore, lock_temporary, sync_directory

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


def previous_module():
    source = HERE / "before/local_object_listing.py"
    spec = importlib.util.spec_from_file_location("listing_before", source)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def previous_constructor(module):
    source = HERE / "before/storage.py"
    cls = next(n for n in ast.parse(source.read_text(encoding="utf-8")).body
               if isinstance(n, ast.ClassDef) and n.name == "LocalBlobStore")
    method = next(n for n in cls.body if isinstance(n, ast.FunctionDef) and n.name == "__init__")
    scope = {"Path": Path, "candidates": module.candidates, "time": time, "logging": logging}
    exec(compile(ast.Module(body=[method], type_ignores=[]), str(source), "exec"), scope)  # noqa: S102
    return scope["__init__"]


def measure(root, module, size, *, constructor=None, default_buffer=io.DEFAULT_BUFFER_SIZE):
    root.mkdir()
    (root / "00").mkdir()
    counters = {"directory_entries": 0, "entry_type_checks": 0, "ordinary_object_stats": 0,
                "shard_link_checks": 0, "manifest_raw_writes": 0, "manifest_raw_bytes": 0}
    original_scan, original_stat = os.scandir, Path.stat
    original_link, original_fdopen = Path.is_symlink, os.fdopen

    def is_file(**_kwargs):
        counters["entry_type_checks"] += 1
        return True

    class Scan:
        def __enter__(self):
            def entries():
                for n in range(size):
                    counters["directory_entries"] += 1
                    yield SimpleNamespace(name=f"{n:064x}.json", is_file=is_file)
            return entries()

        def __exit__(self, *_args):
            pass

    def metadata(path, *args, **kwargs):
        if path.parent == root / "00" and current.OBJECT_NAME.fullmatch(path.name):
            counters["ordinary_object_stats"] += 1
            return SimpleNamespace(st_mode=stat.S_IFREG, st_mtime=0, st_size=1)
        return original_stat(path, *args, **kwargs)

    def linked(path):
        if path == root / "00":
            counters["shard_link_checks"] += 1
        return original_link(path)

    class Raw(io.FileIO):
        def write(self, data):
            counters["manifest_raw_writes"] += 1
            counters["manifest_raw_bytes"] += len(data)
            return super().write(data)

    def fdopen(fd, mode, *args, **kwargs):
        if mode == "wb":
            # Use this interpreter's default or the explicit deployment-3.12
            # 8 KiB profile; preserve any buffering requested by the new code.
            return io.BufferedWriter(Raw(fd, mode), kwargs.get("buffering", default_buffer))
        return original_fdopen(fd, mode, *args, **kwargs)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(os, "scandir", lambda p: Scan() if Path(p) == root / "00" else original_scan(p))
        patch.setattr(Path, "stat", metadata)
        patch.setattr(Path, "is_symlink", linked)
        patch.setattr(os, "fdopen", fdopen)
        if constructor:
            constructor(object.__new__(LocalBlobStore), str(root))
        else:
            cursor = module.prepare_scan(root, None, lock_temporary, sync_directory)
            manifest = root / current.SCAN_DIRECTORY / (cursor["scan"] + ".scan")
            counters["manifest_bytes"] = manifest.stat().st_size
            assert counters["manifest_bytes"] == len(current.HEADER) + size * 73
    return counters


def main():
    old = previous_module()
    base = ROOT / "build/local-object-pagination-optimise-2026-10-22"
    base.mkdir(parents=True, exist_ok=True)
    report = {"scope": __doc__, "interpreter": sys.version,
              "host_default_buffer_bytes": io.DEFAULT_BUFFER_SIZE,
              "new_buffer_bytes": current.MANIFEST_BUFFER_BYTES, "preparation": []}
    with tempfile.TemporaryDirectory(prefix="io-profile-", dir=base) as temporary:
        directory = Path(temporary).resolve()
        assert directory.is_relative_to(base.resolve())
        report["startup_1000_ordinary_objects"] = {
            "before": measure(directory / "startup-before", old, 1005, constructor=previous_constructor(old)),
            "after": measure(directory / "startup-after", current, 1005, constructor=LocalBlobStore.__init__),
        }
        for size in (1000, 10000, 100000):
            before = measure(directory / f"before-{size}", old, size)
            after = measure(directory / f"after-{size}", current, size)
            assert before["directory_entries"] == after["directory_entries"] == size
            assert before["entry_type_checks"] == size and after["entry_type_checks"] == 0
            row = {"objects": size, "before": before, "after": after}
            report["preparation"].append(row)
            print(json.dumps(row), flush=True)
        report["deployment_python312_buffer_profile"] = {
            "baseline_buffer_bytes": 8192,
            "before": measure(directory / "py312-before", old, 100000, default_buffer=8192),
            "after": measure(directory / "py312-after", current, 100000, default_buffer=8192),
        }
    startup = report["startup_1000_ordinary_objects"]
    assert startup["before"]["ordinary_object_stats"] == 1000
    assert startup["after"]["ordinary_object_stats"] == 0
    assert startup["before"]["directory_entries"] == startup["after"]["directory_entries"] == 1000
    (HERE / "benchmark-results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"startup": startup, "deployment_buffer_profile": report["deployment_python312_buffer_profile"]}), flush=True)


if __name__ == "__main__":
    main()
