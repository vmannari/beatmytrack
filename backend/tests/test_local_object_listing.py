"""Durable local continuation, linear directory work and guarded retention."""
import ast
import io
import json
import os
import stat
import subprocess
import sys
import tarfile
import time
from pathlib import Path
from types import SimpleNamespace

import pytest

from bmt_backend import local_object_listing as listing
from bmt_backend.storage import LocalBlobStore, lock_temporary


def collect(store, *, limit=2, cursor=None, temporary=False):
    found = []
    for _ in range(100):
        rows, cursor = store.list_objects(cursor, limit, temporary)
        assert len(rows) <= limit
        found.extend(rows)
        if cursor is None:
            return found
    raise AssertionError("Scan did not finish")


def test_cursor_survives_process_restart_and_retries(tmp_path):
    store = LocalBlobStore(str(tmp_path))
    expected = {store.put_json({"n": n}) for n in range(7)}
    cursor = store.prepare_object_scan()
    first, next_cursor = store.list_objects(cursor, 2)
    assert store.list_objects(cursor, 2) == (first, next_cursor)
    program = """
import json, sys
from bmt_backend.storage import LocalBlobStore
store = LocalBlobStore(sys.argv[1])
cursor = json.loads(sys.argv[2])
items = []
while True:
    rows, cursor = store.list_objects(cursor, 2)
    items.extend(rows)
    if cursor is None: break
print(json.dumps(items))
"""
    result = subprocess.run([sys.executable, "-c", program, str(tmp_path), json.dumps(next_cursor)],
                            capture_output=True, text=True, check=True, timeout=30)
    rest = json.loads(result.stdout)
    assert len(first + rest) == len(expected)
    assert {r["digest"] for r in first + rest} == expected


def test_deletion_does_not_shift_cursor_and_new_objects_wait_for_next_scan(tmp_path):
    store = LocalBlobStore(str(tmp_path))
    expected = {store.put_json({"n": n}) for n in range(11)}
    rows, cursor = store.list_objects(None, 2)
    found = {r["digest"] for r in rows}
    for row in rows:
        store.delete(row["digest"])
    added = store.put_json({"after_snapshot": True})
    while cursor is not None:
        rows, cursor = store.list_objects(cursor, 2)
        found.update(r["digest"] for r in rows)
        for row in rows:
            store.delete(row["digest"])
    assert found == expected
    assert {r["digest"] for r in collect(store)} == {added}


def test_current_type_age_and_missing_files_are_rechecked(tmp_path):
    store = LocalBlobStore(str(tmp_path))
    keys = [store.put_json({"n": n}) for n in range(3)]
    cursor = store.prepare_object_scan()
    store.delete(keys[0])
    stamp = int(time.time()) + 100
    os.utime(store._path(keys[1]), (stamp, stamp))
    store._path(keys[2]).unlink()
    store._path(keys[2]).mkdir()
    rows = collect(store, cursor=cursor, limit=1)
    assert [(r["digest"], r["modified"]) for r in rows] == [(keys[1], stamp)]


def test_legacy_offsets_restart_without_skipping(tmp_path):
    store = LocalBlobStore(str(tmp_path))
    key = store.put_json({"old_cursor": True})
    rows = collect(store, cursor={"shard": 254, "offset": 999999999})
    assert [r["digest"] for r in rows] == [key]


@pytest.mark.parametrize("cursor", [False, [], {}, {"shard": True, "offset": 0},
    {"shard": 257, "offset": 0}, {"shard": 0, "offset": -1},
    {"v": 1, "scan": "../other", "offset": 23},
    {"v": True, "scan": "a" * 32, "offset": 23}])
def test_invalid_cursors_do_not_prepare_a_scan(tmp_path, cursor):
    store = LocalBlobStore(str(tmp_path))
    with pytest.raises(ValueError):
        store.list_objects(cursor, 10)
    assert not (tmp_path / listing.SCAN_DIRECTORY).exists()


@pytest.mark.parametrize("limit", [True, 0, -1, 1001, 1.5])
def test_invalid_page_size_does_not_prepare_a_scan(tmp_path, limit):
    store = LocalBlobStore(str(tmp_path))
    with pytest.raises(ValueError):
        store.list_objects(None, limit)
    assert not (tmp_path / listing.SCAN_DIRECTORY).exists()


def test_cursor_boundaries_expiry_and_corruption(tmp_path):
    store = LocalBlobStore(str(tmp_path))
    store.put_json({"one": 1})
    cursor = store.prepare_object_scan()
    path = tmp_path / listing.SCAN_DIRECTORY / (cursor["scan"] + ".scan")
    with pytest.raises(ValueError, match="boundary"):
        store.list_objects({**cursor, "offset": cursor["offset"] + 1}, 1)
    with pytest.raises(ValueError, match="cursor"):
        store.list_objects({**cursor, "offset": 10000}, 1)
    path.write_bytes(listing.HEADER + b"00/../../outside\n")
    with pytest.raises(ValueError, match="record"):
        store.list_objects(cursor, 1)
    expired = time.time() - listing.SCAN_TTL_SECONDS - 1
    os.utime(path, (expired, expired))
    with pytest.raises(ValueError, match="expired"):
        store.list_objects(cursor, 1)
    replacement = store.prepare_object_scan()
    assert not path.exists()
    assert replacement["scan"] != cursor["scan"]


def test_builder_lock_releases_on_failure_and_pending_is_reclaimed(tmp_path, monkeypatch):
    store = LocalBlobStore(str(tmp_path))
    original = listing.candidates

    def fail(_root):
        raise OSError("interrupted scan")

    monkeypatch.setattr(listing, "candidates", fail)
    with pytest.raises(OSError, match="interrupted"):
        store.prepare_object_scan()
    directory = tmp_path / listing.SCAN_DIRECTORY
    assert not list(directory.glob("*.pending"))
    leftover = directory / ("a" * 32 + ".pending")
    leftover.write_bytes(b"partial")
    monkeypatch.setattr(listing, "candidates", original)
    store.prepare_object_scan()
    assert not leftover.exists()
    with (directory / "builder.lock").open("r+b") as guard:
        assert lock_temporary(guard)
        # A second process must not prepare or reclaim anything while owned.
        result = subprocess.run([sys.executable, "-c",
            "from bmt_backend.storage import LocalBlobStore; import sys; LocalBlobStore(sys.argv[1]).prepare_object_scan()",
            str(tmp_path)], capture_output=True, text=True, timeout=30, check=False)
        assert result.returncode != 0 and "being prepared" in result.stderr


def test_active_scan_cap_and_completed_reclamation(tmp_path):
    store = LocalBlobStore(str(tmp_path))
    store.put_json({"one": 1})
    cursors = [store.prepare_object_scan() for _ in range(listing.MAX_ACTIVE_SCANS)]
    with pytest.raises(OSError, match="capacity"):
        store.prepare_object_scan()
    assert store.list_objects(cursors[0], 1)[1] is None
    # Final-page retry works before a new scan reclaims completed artifacts.
    assert store.list_objects(cursors[0], 1)[1] is None
    store.prepare_object_scan()
    with pytest.raises(ValueError, match="expired"):
        store.list_objects(cursors[0], 1)
    directory = tmp_path / listing.SCAN_DIRECTORY
    assert len(list(directory.glob("*.scan"))) == listing.MAX_ACTIVE_SCANS


def test_manifest_metadata_symlink_is_rejected_and_resume_never_enumerates(tmp_path, monkeypatch):
    store = LocalBlobStore(str(tmp_path))
    store.put_json({"one": 1})
    cursor = store.prepare_object_scan()
    with monkeypatch.context() as patch:
        def forbidden(_path):
            raise AssertionError("Resumed page enumerated a directory")
        patch.setattr(listing.os, "scandir", forbidden)
        assert len(store.list_objects(cursor, 1)[0]) == 1
    actual = Path.is_symlink
    with monkeypatch.context() as patch:
        patch.setattr(Path, "is_symlink", lambda path: path.name == listing.SCAN_DIRECTORY or actual(path))
        with pytest.raises(OSError, match="real directory"):
            store.list_objects(cursor, 1)


def test_local_backup_round_trip_excludes_scan_artifacts(tmp_path):
    root, target = tmp_path / "source", tmp_path / "restored"
    store = LocalBlobStore(str(root))
    expected = {store.put_json({"n": n}) for n in range(3)}
    store.prepare_object_scan()
    script = Path(__file__).resolve().parents[1] / "deploy/object_archive.py"
    archive = subprocess.run([sys.executable, str(script), "archive", "--root", str(root)],
        capture_output=True, timeout=30, check=True, env=os.environ | {"BMT_OBJECT_BACKEND": "local"})
    with tarfile.open(fileobj=io.BytesIO(archive.stdout)) as stream:
        assert not any(listing.SCAN_DIRECTORY in entry.name for entry in stream)
    subprocess.run([sys.executable, str(script), "restore", "--root", str(target)],
        input=archive.stdout, capture_output=True, timeout=30, check=True)
    restored = LocalBlobStore(str(target))
    assert {row["digest"] for row in collect(restored)} == expected
    assert {restored.get_json(key)["n"] for key in expected} == {0, 1, 2}


def test_startup_work_stays_bounded_without_manifest(tmp_path, monkeypatch):
    directory = tmp_path / "00"
    directory.mkdir()
    for n in range(1005):
        (directory / f"{n:064x}.json").write_bytes(b"{}")
    original = listing.os.scandir
    original_stat = Path.stat
    advanced, ordinary_stats = 0, 0

    def count_stat(path, *args, **kwargs):
        nonlocal ordinary_stats
        if path.parent == directory and listing.OBJECT_NAME.fullmatch(path.name):
            ordinary_stats += 1
        return original_stat(path, *args, **kwargs)

    class Scan:
        def __enter__(self):
            self.stream = original(directory)
            def rows():
                nonlocal advanced
                for row in self.stream:
                    advanced += 1
                    yield row
            return rows()

        def __exit__(self, *_args):
            self.stream.close()

    monkeypatch.setattr(listing.os, "scandir", lambda _path: Scan())
    monkeypatch.setattr(Path, "stat", count_stat)
    LocalBlobStore(str(tmp_path))
    assert advanced == 1000
    assert ordinary_stats == 0
    assert not (tmp_path / listing.SCAN_DIRECTORY).exists()


def test_preparation_uses_names_and_page_rechecks_file_type(tmp_path, monkeypatch):
    store = LocalBlobStore(str(tmp_path))
    key = store.put_json({"candidate": True})
    directory = store._path(key).parent
    original = os.scandir

    def forbidden(**_kwargs):
        raise AssertionError("Preparation fetched per-entry metadata")

    class Scan:
        def __enter__(self):
            return iter([SimpleNamespace(name=store._path(key).name, is_file=forbidden)])

        def __exit__(self, *_args):
            pass

    monkeypatch.setattr(os, "scandir", lambda path: Scan() if Path(path) == directory else original(path))
    cursor = store.prepare_object_scan()
    # A valid-looking directory name may enter the name-only manifest; the
    # authoritative current type check must still exclude it when consumed.
    store._path(key).unlink()
    store._path(key).mkdir()
    assert store.list_objects(cursor, 1) == ([], None)


def test_directory_and_link_types_are_excluded_from_name_only_manifest_pages(tmp_path, monkeypatch):
    store = LocalBlobStore(str(tmp_path))
    key = store.put_json({"regular": True})
    directory_key, link_key = "0" * 64, "1" * 64
    directory = store._path(directory_key)
    directory.parent.mkdir(exist_ok=True)
    directory.mkdir()
    link = store._path(link_key)
    link.parent.mkdir(exist_ok=True)
    link.write_bytes(b"stand-in for a filesystem link")
    original_stat = Path.stat

    def metadata(path, *args, **kwargs):
        if path == link:
            assert kwargs.get("follow_symlinks") is False
            return SimpleNamespace(st_mode=stat.S_IFLNK)
        return original_stat(path, *args, **kwargs)

    monkeypatch.setattr(Path, "stat", metadata)
    assert [row["digest"] for row in collect(store, limit=1)] == [key]
    assert directory.is_dir() and link.exists()


def test_page_does_not_read_past_requested_records(tmp_path, monkeypatch):
    store = LocalBlobStore(str(tmp_path))
    for n in range(3):
        store.put_json({"n": n})
    cursor = store.prepare_object_scan()
    fdopen = os.fdopen

    class Reader:
        def __init__(self, stream):
            self.stream, self.boundary_reads = stream, 0

        def __getattr__(self, name):
            return getattr(self.stream, name)

        def __enter__(self):
            return self

        def __exit__(self, *args):
            return self.stream.__exit__(*args)

        def read(self, size):
            if size == 1:
                self.boundary_reads += 1
                assert self.boundary_reads == 1, "Page read ahead only to check for another page"
            return self.stream.read(size)

    monkeypatch.setattr(os, "fdopen", lambda fd, mode, *args, **kwargs:
        Reader(fdopen(fd, mode, *args, **kwargs)) if mode == "rb" else fdopen(fd, mode, *args, **kwargs))
    rows, next_cursor = store.list_objects(cursor, 1)
    assert len(rows) == 1 and next_cursor is not None


def test_shared_shard_path_still_rechecks_each_directory_guard(tmp_path, monkeypatch):
    store = LocalBlobStore(str(tmp_path))
    directory = tmp_path / "00"
    directory.mkdir()
    names = [f"{n:064x}.json" for n in range(2)]
    for name in names:
        (directory / name).write_bytes(b"{}")
    original = Path.is_symlink
    checks = 0

    def changed(path):
        nonlocal checks
        if path == directory:
            checks += 1
            return checks > 1
        return original(path)

    monkeypatch.setattr(Path, "is_symlink", changed)
    rows = list(store._candidate_rows((("00", name) for name in names), False))
    assert checks == 2 and [row["digest"] for row in rows] == [names[0][:64]]


def directory_work(root, size, monkeypatch, method):
    """Actual listing, simulated entries; real disk manifest and page seeks."""
    root.mkdir()
    (root / "00").mkdir()
    store = object.__new__(LocalBlobStore)
    store.root = root
    original_scan, original_stat = os.scandir, Path.stat
    advanced = 0

    class Scan:
        def __enter__(self):
            def rows():
                nonlocal advanced
                for n in range(size):
                    advanced += 1
                    yield SimpleNamespace(name=f"{n:064x}.json", is_file=lambda **_kw: True,
                        stat=lambda **_kw: SimpleNamespace(st_mtime=0, st_size=1))
            return rows()

        def __exit__(self, *_args):
            pass

    def fake_stat(path, *args, **kwargs):
        if path.parent == root / "00" and listing.OBJECT_NAME.fullmatch(path.name):
            return SimpleNamespace(st_mode=stat.S_IFREG, st_mtime=0, st_size=1)
        return original_stat(path, *args, **kwargs)

    with monkeypatch.context() as patch:
        patch.setattr(os, "scandir", lambda p: Scan() if Path(p) == root / "00" else original_scan(p))
        patch.setattr(Path, "stat", fake_stat)
        cursor, returned = None, 0
        for _ in range(size // 1000 + 2):
            rows, cursor = method(store, cursor, 1000)
            returned += len(rows)
            if cursor is None:
                break
        assert cursor is None and returned == size
    return advanced


@pytest.mark.parametrize("size", [1000, 10000, 100000])
def test_full_scan_directory_work_is_linear(tmp_path, monkeypatch, size):
    assert directory_work(tmp_path / "current", size, monkeypatch, LocalBlobStore.list_objects) == size


def test_saved_original_reproduces_quadratic_work(tmp_path, monkeypatch):
    source = Path(__file__).resolve().parents[2] / "docs/evidence/local-object-pagination-2026-10-22/before/storage.py"
    tree = ast.parse(source.read_text(encoding="utf-8"))
    cls = next(n for n in tree.body if isinstance(n, ast.ClassDef) and n.name == "LocalBlobStore")
    method = next(n for n in cls.body if isinstance(n, ast.FunctionDef) and n.name == "list_objects")
    scope = {"os": os, "re": __import__("re"), "TEMPORARY_NAME": listing.TEMPORARY_NAME}
    exec(compile(ast.Module(body=[method], type_ignores=[]), str(source), "exec"), scope)  # noqa: S102 - saved source fixture
    assert directory_work(tmp_path / "original", 100000, monkeypatch, scope["list_objects"]) == 5150000
