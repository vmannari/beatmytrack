"""Immutable content-addressed storage boundary; local, S3 and native Google storage."""

import gzip
import hashlib
import io
import json
import logging
import os
import re
import stat
import tempfile
import time
from pathlib import Path
from typing import Protocol

from .json_data import parse_json

MAX_BLOB_BYTES = 8 * 1024 * 1024
MAX_STORED_BLOB_BYTES = MAX_BLOB_BYTES + 65536
TEMPORARY_NAME = re.compile(r"\.pending-[A-Za-z0-9_-]{6,80}(?:\.guard)?")


def decode_blob_json(body: bytes, digest: str) -> dict:
    """Verify the exact stored bytes, including bounded decompression, before use."""
    if len(body) > MAX_STORED_BLOB_BYTES:
        raise OSError("Stored object exceeds limit")
    if body.startswith(b"\x1f\x8b"):
        try:
            with gzip.GzipFile(fileobj=io.BytesIO(body)) as source:
                body = source.read(MAX_BLOB_BYTES + 1)
        except (OSError, EOFError) as exc:
            raise OSError("Object compression integrity check failed") from exc
    if len(body) > MAX_BLOB_BYTES or hashlib.sha256(body).hexdigest() != digest:
        raise OSError("Object integrity check failed")
    try:
        # Packed ingress expands into canonical frames before storage. Keep its
        # byte-bound maximum, while sharing finite/Unicode/key/depth checks.
        data = parse_json(body, maximum_nodes=MAX_BLOB_BYTES)
    except (ValueError, UnicodeError, RecursionError) as exc:
        raise OSError("Invalid stored object") from exc
    if not isinstance(data, dict):
        raise OSError("Invalid stored object")
    return data


def sync_directory(path):
    if os.name != "nt":
        directory = os.open(path, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)


def lock_temporary(stream):
    """OS-released nonblocking lock; a separate guard leaves blob reads usable."""
    stream.seek(0)
    try:
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(stream.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except (BlockingIOError, PermissionError):
        return False
    return True


def canonical_json(data: dict) -> bytes:
    return json.dumps(
        data, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False
    ).encode("utf-8")


class BlobStore(Protocol):
    def put_json(self, data: dict) -> str: ...
    def get_json(self, digest: str) -> dict: ...
    def list_objects(self, cursor: dict | None, limit: int) -> tuple[list[dict], dict | None]: ...
    def delete(self, digest: str) -> None: ...


class LocalBlobStore:
    def __init__(self, root: str):
        self.root = Path(root).resolve()
        self.root.mkdir(parents=True, exist_ok=True)
        # Startup is a single bounded pass. Retention's resumable cursor reaches
        # later shards; active writers and legacy unguarded files stay intact.
        try:
            rows, _cursor = self.list_objects(None, 1000, True)
            for row in rows:
                if "temporary" in row:
                    self.cleanup_temporary(row, time.time()-86400, apply=True)
        except OSError as exc:
            logging.getLogger("bmt.storage").warning("temporary_cleanup_unavailable",
                extra={"exception_type": type(exc).__name__})

    def _path(self, digest: str) -> Path:
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid object digest")
        return self.root / digest[:2] / (digest + ".json")

    def put_json(self, data: dict) -> str:
        body = canonical_json(data)
        if len(body) > 8 * 1024 * 1024:
            raise ValueError("Object exceeds limit")
        digest = hashlib.sha256(body).hexdigest()
        path = self._path(digest)
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists():
            self.get_json(digest)  # Detect disk corruption instead of silently trusting it.
            # A previous attempt may have linked the final name but failed its
            # directory flush. Reuse must finish durability before acknowledging.
            sync_directory(self.root)
            sync_directory(path.parent)
            return digest
        # Also persists a shard created by a concurrent first publisher.
        sync_directory(self.root)
        fd, temporary = tempfile.mkstemp(prefix=".pending-", dir=path.parent)
        guard = None
        try:
            with os.fdopen(fd, "wb") as stream:
                guard = open(temporary + ".guard", "x+b")  # noqa: SIM115 - closed in finally; guards publication after stream close
                guard.write(b"0")
                guard.flush()
                if not lock_temporary(guard):
                    raise OSError("Temporary object guard unavailable")
                stream.write(gzip.compress(body, compresslevel=3, mtime=0) if len(body) >= 1024 else body)
                stream.flush()
                os.fsync(stream.fileno())
            # Publish without replacing an existing immutable inode. In
            # particular, Windows readers can deny replacement of an open file.
            try:
                os.link(temporary, path)
            except FileExistsError:
                self.get_json(digest)
            sync_directory(path.parent)
        finally:
            try:
                Path(temporary).unlink(missing_ok=True)
            finally:
                if guard is not None:
                    guard.close()
                    Path(temporary + ".guard").unlink(missing_ok=True)
        return digest

    def get_json(self, digest: str) -> dict:
        path = self._path(digest)
        with path.open("rb") as stream:
            body = stream.read(MAX_STORED_BLOB_BYTES + 1)
        return decode_blob_json(body, digest)

    def delete(self, digest):
        self._path(digest).unlink(missing_ok=True)

    def list_objects(self, cursor, limit, include_temporary=False):
        from itertools import islice
        cursor = cursor or {"shard":0,"offset":0}
        shard, offset = cursor["shard"], cursor["offset"]
        inspected, rows = 0, []
        while shard < 256 and inspected < limit:
            directory = self.root / f"{shard:02x}"
            if not directory.is_dir() or directory.is_symlink():
                shard, offset = shard+1, 0
                continue
            with os.scandir(directory) as stream:
                exhausted = True
                for entry in islice(stream, offset, None):
                    inspected, offset = inspected+1, offset+1
                    name = entry.name
                    if (entry.is_file(follow_symlinks=False) and re.fullmatch(r"[0-9a-f]{64}\.json", name)
                            and name.startswith(directory.name)):
                        info = entry.stat(follow_symlinks=False)
                        rows.append({"digest":name[:64],"modified":int(info.st_mtime),"bytes":info.st_size})
                    elif (include_temporary and TEMPORARY_NAME.fullmatch(name)
                            and entry.is_file(follow_symlinks=False)):
                        info = entry.stat(follow_symlinks=False)
                        rows.append({"temporary": name, "shard": directory.name,
                                     "modified": int(info.st_mtime), "bytes": info.st_size})
                    if inspected >= limit:
                        exhausted = False
                        break
                if exhausted:
                    shard, offset = shard+1, 0
        return rows, {"shard":shard,"offset":offset} if shard < 256 else None

    def cleanup_temporary(self, row, cutoff, *, apply=False, offline=False):
        """Clean only aged, unlocked writer groups from the bounded GC scan.

        Old unguarded files require stopped writers: an older deployed process
        cannot advertise its active write to this version's advisory guards.
        """
        name, shard = row["temporary"], row["shard"]
        if not TEMPORARY_NAME.fullmatch(name) or not re.fullmatch(r"[0-9a-f]{2}", shard):
            raise ValueError("Invalid temporary object identity")
        directory = self.root / shard
        if directory.is_symlink():
            return [], 0
        path = directory / name
        data = path.with_name(name.removesuffix(".guard"))
        guard_path = data.with_name(data.name + ".guard")
        orphan_guard = name.endswith(".guard")
        if orphan_guard and data.exists():
            return [], 0
        lock_path = guard_path if guard_path.exists() else data
        if lock_path == data and not offline:
            return [], 0
        try:
            fd = os.open(lock_path, os.O_RDWR | getattr(os, "O_NOFOLLOW", 0))
        except FileNotFoundError:
            return [], 0
        except PermissionError:
            return [], 0
        with os.fdopen(fd, "r+b") as guard:
            info = os.fstat(guard.fileno())
            try:
                current = lock_path.stat(follow_symlinks=False)
            except FileNotFoundError:
                return [], 0
            if (not stat.S_ISREG(info.st_mode) or not stat.S_ISREG(current.st_mode)
                    or (info.st_dev, info.st_ino) != (current.st_dev, current.st_ino)
                    or not lock_temporary(guard)):
                return [], 0
            try:
                info = path.stat(follow_symlinks=False)
            except FileNotFoundError:
                return [], 0
            if not stat.S_ISREG(info.st_mode) or info.st_mtime >= cutoff:
                return [], 0
            names, size = [name], info.st_size
            if not orphan_guard and lock_path == guard_path:
                names.append(guard_path.name)
                size += os.fstat(guard.fileno()).st_size
            if apply and not orphan_guard and lock_path == guard_path:
                path.unlink(missing_ok=True)
        # Windows cannot remove an open guard. Legitimate writers never reuse a
        # temporary name, and its data was removed while the guard was locked.
        if apply:
            for entry in names:
                try:
                    (directory / entry).unlink(missing_ok=True)
                except PermissionError:
                    # A concurrent cleanup may still hold the orphan guard.
                    if not entry.endswith(".guard"):
                        raise
        return names, size


class PinnedBlobStore:
    """A shared DB pin precedes every publication and read, including reused hashes.

    GC locks the same hash and rechecks references. The pin outlives bounded API
    transactions and verifier leases; a process crash cannot leak a permanent pin.
    """
    def __init__(self, store, factory, lease_seconds=600):
        self.store, self.factory, self.lease_seconds = store, factory, lease_seconds

    def __getattr__(self, name):
        return getattr(self.store, name)

    def _pin(self, digest):
        from sqlalchemy.dialects.postgresql import insert as pg_insert
        from sqlalchemy.dialects.sqlite import insert as sqlite_insert

        from .object_models import ObjectPin
        from .track_models import now
        with self.factory() as session:
            insert = sqlite_insert if session.bind.dialect.name == "sqlite" else pg_insert
            statement = insert(ObjectPin).values(digest=digest, expires_at=now()+self.lease_seconds)
            session.execute(statement.on_conflict_do_update(index_elements=[ObjectPin.digest],
                set_={"expires_at":statement.excluded.expires_at}))
            session.commit()

    def put_json(self, data):
        body = canonical_json(data)
        if len(body) > 8*1024*1024:
            raise ValueError("Object exceeds limit")
        key = hashlib.sha256(body).hexdigest()
        self._pin(key)
        return self.store.put_json(data)

    def get_json(self, digest):
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid object digest")
        self._pin(digest)
        return self.store.get_json(digest)

    def release_probe_pin(self, digest: str) -> None:
        """Remove only the caller's ephemeral readiness-object pin after IO."""
        from sqlalchemy import delete

        from .object_models import ObjectPin
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError("Invalid probe digest")
        with self.factory() as session:
            session.execute(delete(ObjectPin).where(ObjectPin.digest == digest))
            session.commit()


def make_blob_store(settings, factory):
    if settings.object_backend == "s3":
        from .s3_storage import S3BlobStore
        store = S3BlobStore(settings)
    elif settings.object_backend == "gcs":
        from .gcs_storage import GCSBlobStore
        store = GCSBlobStore(settings)
    else:
        store = LocalBlobStore(settings.object_dir)
    return PinnedBlobStore(store, factory, max(600,settings.job_lease_seconds+60))
