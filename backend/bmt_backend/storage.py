"""Immutable content-addressed storage boundary; local, S3 and native Google storage."""

import gzip
import hashlib
import io
import json
import os
import re
import tempfile
from pathlib import Path
from typing import Protocol


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
            return digest
        fd, temporary = tempfile.mkstemp(prefix=".pending-", dir=path.parent)
        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(gzip.compress(body, compresslevel=3, mtime=0) if len(body) >= 1024 else body)
                stream.flush()
                os.fsync(stream.fileno())
            # Publish without replacing an existing immutable inode. In
            # particular, Windows readers can deny replacement of an open file.
            try:
                os.link(temporary, path)
            except FileExistsError:
                self.get_json(digest)
            if os.name != "nt":
                directory = os.open(path.parent, os.O_RDONLY)
                try:
                    os.fsync(directory)
                finally:
                    os.close(directory)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        return digest

    def get_json(self, digest: str) -> dict:
        path = self._path(digest)
        with path.open("rb") as stream:
            body = stream.read(8 * 1024 * 1024 + 1)
        if body.startswith(b"\x1f\x8b"):
            try:
                with gzip.GzipFile(fileobj=io.BytesIO(body)) as source:
                    body = source.read(8 * 1024 * 1024 + 1)
            except (OSError, EOFError) as exc:
                raise OSError("Object compression integrity check failed") from exc
        if len(body) > 8 * 1024 * 1024 or hashlib.sha256(body).hexdigest() != digest:
            raise OSError("Object integrity check failed")
        data = json.loads(body)
        if not isinstance(data, dict):
            raise OSError("Invalid stored object")
        return data

    def delete(self, digest):
        self._path(digest).unlink(missing_ok=True)

    def list_objects(self, cursor, limit):
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
                    if inspected >= limit:
                        exhausted = False
                        break
                if exhausted:
                    shard, offset = shard+1, 0
        return rows, {"shard":shard,"offset":offset} if shard < 256 else None


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
