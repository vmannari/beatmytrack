"""Offline regression tests for archive data safety; no Docker or real data used."""

from __future__ import annotations

import gzip
import hashlib
import io
import os
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

from bmt_backend.storage import MAX_BLOB_BYTES, LocalBlobStore

HELPER = Path(__file__).with_name("object_archive.py")


class ArchiveTests(unittest.TestCase):
    def call(self, operation: str, root: Path, data: bytes = b""):
        return subprocess.run(
            [sys.executable, str(HELPER), operation, "--root", str(root)],
            input=data,
            capture_output=True,
            check=False,
            env=os.environ | {"BMT_OBJECT_BACKEND": "local"},
        )

    def payload(self, name="valid.json", kind=tarfile.REGTYPE):
        output = io.BytesIO()
        with tarfile.open(fileobj=output, mode="w") as archive:
            entry = tarfile.TarInfo(name)
            entry.type = kind
            if kind == tarfile.REGTYPE:
                entry.size = 2
                archive.addfile(entry, io.BytesIO(b"{}"))
            else:
                entry.linkname = "../../outside"
                archive.addfile(entry)
        return output.getvalue()

    def test_real_round_trip_and_nonempty_refusal(self):
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            source, destination = base / "source", base / "destination"
            store = LocalBlobStore(str(source))
            key = store.put_json({"hello": "world"})
            backup = self.call("archive", source)
            self.assertEqual(backup.returncode, 0, backup.stderr)
            restored = self.call("restore", destination, backup.stdout)
            self.assertEqual(restored.returncode, 0, restored.stderr)
            self.assertEqual(LocalBlobStore(str(destination)).get_json(key), {"hello": "world"})
            self.assertNotEqual(self.call("restore", destination, backup.stdout).returncode, 0)
            self.assertEqual(LocalBlobStore(str(destination)).get_json(key), {"hello": "world"})

    def test_traversal_absolute_paths_and_links_rejected(self):
        for name, kind in (
            ("../outside", tarfile.REGTYPE),
            ("/outside", tarfile.REGTYPE),
            ("C:/outside", tarfile.REGTYPE),
            ("..\\outside", tarfile.REGTYPE),
            ("link", tarfile.SYMTYPE),
            ("hardlink", tarfile.LNKTYPE),
            ("fifo", tarfile.FIFOTYPE),
        ):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as temp:
                root = Path(temp) / "objects"
                result = self.call("restore", root, self.payload(name, kind))
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse((Path(temp) / "outside").exists())

    def test_duplicate_entries_never_overwrite(self):
        data = io.BytesIO()
        original = b'{"value":"original"}'
        key = hashlib.sha256(original).hexdigest()
        with tarfile.open(fileobj=data, mode="w") as archive:
            for payload in (original, original):
                member = tarfile.TarInfo(key[:2] + "/" + key + ".json")
                member.size = len(payload)
                archive.addfile(member, io.BytesIO(payload))
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "objects"
            self.assertNotEqual(self.call("restore", root, data.getvalue()).returncode, 0)
            self.assertEqual((root / key[:2] / (key + ".json")).read_bytes(), original)

    def test_interrupted_hardlink_publication_round_trip(self):
        with tempfile.TemporaryDirectory() as temp:
            source, destination = Path(temp) / "source", Path(temp) / "restored"
            body = b'{"complete":"object"}'
            key = hashlib.sha256(body).hexdigest()
            directory = source / key[:2]
            directory.mkdir(parents=True)
            (directory / ".pending-write").write_bytes(body)
            os.link(directory / ".pending-write", directory / (key + ".json"))
            backup = self.call("archive", source)
            self.assertEqual(backup.returncode, 0, backup.stderr)
            restored = self.call("restore", destination, backup.stdout)
            self.assertEqual(restored.returncode, 0, restored.stderr)
            self.assertEqual(LocalBlobStore(str(destination)).get_json(key), {"complete": "object"})

    def test_invalid_content_and_decompression_bomb_never_publish_a_file(self):
        for raw, compressed in ((b'[]', False), (b'{"x":NaN}', False), (b'{"x":1e400}', False),
                (b'{"x":1,"x":2}', True), (b'{"x":"\\ud800"}', True),
                (b'{"x":"' + b'x' * MAX_BLOB_BYTES + b'"}', True)):
            with self.subTest(compressed=compressed), tempfile.TemporaryDirectory() as temp:
                key = hashlib.sha256(raw).hexdigest()
                body = gzip.compress(raw) if compressed else raw
                output = io.BytesIO()
                with tarfile.open(fileobj=output, mode="w") as archive:
                    entry = tarfile.TarInfo(key[:2] + "/" + key + ".json")
                    entry.size = len(body)
                    archive.addfile(entry, io.BytesIO(body))
                root = Path(temp) / "restore"
                self.assertNotEqual(self.call("restore", root, output.getvalue()).returncode, 0)
                self.assertFalse((root / key[:2] / (key + ".json")).exists())


if __name__ == "__main__":
    unittest.main()
