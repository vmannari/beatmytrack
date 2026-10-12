"""Stream immutable object backups; restore only into an empty volume, no links."""

from __future__ import annotations

import argparse
import gzip
import io
import os
import shutil
import sys
import tarfile
from pathlib import Path, PurePosixPath


def require_empty(root: Path) -> None:
    if root.is_symlink():
        raise ValueError("Object root must not be a symbolic link")
    if root.exists() and any(root.iterdir()):
        raise ValueError("Restore requires an empty object volume")


def archive(root: Path) -> None:
    provider = os.environ.get("BMT_OBJECT_BACKEND", "local")
    if provider in ("s3", "gcs"):
        from bmt_backend.config import Settings
        settings = Settings.from_env()
        if provider == "gcs":
            from bmt_backend.gcs_storage import GCSBlobStore
            store = GCSBlobStore(settings)
        else:
            from bmt_backend.s3_storage import S3BlobStore
            store = S3BlobStore(settings)
        archive_objects(store)
        return
    # An interrupted atomic publish can leave the temporary and final names linked.
    # Serialize both as regular data; restoring archive link entries is forbidden.
    with tarfile.open(fileobj=sys.stdout.buffer, mode="w|", dereference=True) as output:
        for directory, folders, files in os.walk(root, followlinks=False):
            # Only one hash shard's names are resident, regardless of total size.
            for name in sorted(folders + files):
                if name.startswith(".pending-"):
                    continue
                source = Path(directory) / name
                if source.is_symlink() or not (source.is_file() or source.is_dir()):
                    raise ValueError("Only regular object files and directories can be backed up")
                output.add(source, arcname=source.relative_to(root).as_posix(), recursive=False)


def archive_objects(store) -> None:
    """Stream one bounded provider object at a time into the portable local format."""
    from bmt_backend.storage import canonical_json
    cursor = None
    with tarfile.open(fileobj=sys.stdout.buffer, mode="w|", dereference=True) as output:
        while True:
            rows, cursor = store.list_objects(cursor, 1000)
            for row in rows:
                key = row["digest"]
                payload = gzip.compress(canonical_json(store.get_json(key)), compresslevel=3, mtime=0)
                entry = tarfile.TarInfo(key[:2]+"/"+key+".json")
                entry.size = len(payload)
                output.addfile(entry, io.BytesIO(payload))
            if cursor is None:
                break


def restore(root: Path) -> None:
    require_empty(root)
    root.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=sys.stdin.buffer, mode="r|") as source:
        for member in source:
            relative = PurePosixPath(member.name)
            if relative.is_absolute() or ".." in relative.parts or "\\" in member.name or ":" in member.name:
                raise ValueError("Invalid object archive path")
            if not (member.isfile() or member.isdir()) or member.islnk() or member.issym():
                raise ValueError("Archive links and special files are forbidden")
            destination = root.joinpath(*relative.parts)
            if member.isdir():
                destination.mkdir(parents=True, exist_ok=True)
            else:
                destination.parent.mkdir(parents=True, exist_ok=True)
                payload = source.extractfile(member)
                if payload is None:
                    raise ValueError("Object archive file has no content")
                # Exclusive create rejects duplicate file entries and never overwrites.
                with payload, destination.open("xb") as output:
                    shutil.copyfileobj(payload, output)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("archive", "restore", "check-empty"))
    parser.add_argument("--root", type=Path, default=Path("/var/lib/bmt/objects"))
    args = parser.parse_args()
    {"archive": archive, "restore": restore, "check-empty": require_empty}[args.operation](args.root)
