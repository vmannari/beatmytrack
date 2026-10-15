"""Immutable, minimal erasure records outside the ordinary object/backup namespace."""
import hashlib
import json
from dataclasses import replace
from pathlib import Path

from .storage import LocalBlobStore


def make_journal(settings):
    # Deliberately unpinned: this separate namespace has no ordinary object GC.
    if settings.object_backend == "gcs":
        from .gcs_storage import GCSBlobStore
        return GCSBlobStore(replace(settings, gcs_prefix="bmt-erasure-v1/" + hashlib.sha256(settings.gcs_prefix.encode()).hexdigest()))
    if settings.object_backend == "s3":
        from .s3_storage import S3BlobStore
        return S3BlobStore(replace(settings, s3_prefix="bmt-erasure-v1/" + hashlib.sha256(settings.s3_prefix.encode()).hexdigest()))
    root = Path(settings.object_dir)
    return LocalBlobStore(str(root.with_name(root.name + "-erasure")))


def export_journal(store, path):
    """Works even when the primary DB is lost. Freeze writes during restore/export."""
    from uuid import UUID
    target = Path(path)
    temporary = target.with_name(target.name + ".tmp")
    cursor, count = None, 0
    with temporary.open("w", encoding="utf-8") as stream:
        stream.write(json.dumps({"schema": "bmt-erasure-ledger-v1"}) + "\n")
        while True:
            rows, cursor = store.list_objects(cursor, 1000)
            for row in rows:
                if "temporary" in row:
                    continue
                record = store.get_json(row["digest"])
                if (set(record) != {"schema", "player_id", "requested_at"}
                        or record["schema"] != "bmt-erasure-record-v1"
                        or str(UUID(record["player_id"])) != record["player_id"]
                        or type(record["requested_at"]) is not int or record["requested_at"] <= 0):
                    raise ValueError("Invalid erasure journal; keep the restored service offline")
                stream.write(json.dumps({"player_id": record["player_id"], "requested_at": record["requested_at"]}) + "\n")
                count += 1
            if cursor is None:
                break
    temporary.replace(target)
    return count
