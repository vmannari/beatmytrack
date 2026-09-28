"""Immutable content-addressed storage boundary; shared volume on NAS, S3 adapter later."""

import hashlib
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
                stream.write(body)
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
        if len(body) > 8 * 1024 * 1024 or hashlib.sha256(body).hexdigest() != digest:
            raise OSError("Object integrity check failed")
        data = json.loads(body)
        if not isinstance(data, dict):
            raise OSError("Invalid stored object")
        return data
