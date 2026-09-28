"""Offline regression tests for archive data safety; no Docker or real data used."""

from __future__ import annotations

import io
import os
import subprocess
import sys
import tarfile
import tempfile
import unittest
from pathlib import Path

HELPER = Path(__file__).with_name("object_archive.py")


class ArchiveTests(unittest.TestCase):
    def call(self, operation: str, root: Path, data: bytes = b""):
        return subprocess.run(
            [sys.executable, str(HELPER), operation, "--root", str(root)],
            input=data,
            capture_output=True,
            check=False,
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
            (source / "ab").mkdir(parents=True)
            (source / "ab" / "object.json").write_bytes(b'{"hello":"world"}')
            backup = self.call("archive", source)
            self.assertEqual(backup.returncode, 0, backup.stderr)
            restored = self.call("restore", destination, backup.stdout)
            self.assertEqual(restored.returncode, 0, restored.stderr)
            self.assertEqual((destination / "ab" / "object.json").read_bytes(), b'{"hello":"world"}')
            self.assertNotEqual(self.call("restore", destination, backup.stdout).returncode, 0)
            self.assertEqual((destination / "ab" / "object.json").read_bytes(), b'{"hello":"world"}')

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
        with tarfile.open(fileobj=data, mode="w") as archive:
            for payload in (b"original", b"modified"):
                member = tarfile.TarInfo("object.json")
                member.size = len(payload)
                archive.addfile(member, io.BytesIO(payload))
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp) / "objects"
            self.assertNotEqual(self.call("restore", root, data.getvalue()).returncode, 0)
            self.assertEqual((root / "object.json").read_bytes(), b"original")

    def test_interrupted_hardlink_publication_round_trip(self):
        with tempfile.TemporaryDirectory() as temp:
            source, destination = Path(temp) / "source", Path(temp) / "restored"
            source.mkdir()
            (source / ".pending-write").write_bytes(b"complete-object")
            os.link(source / ".pending-write", source / "published.json")
            backup = self.call("archive", source)
            self.assertEqual(backup.returncode, 0, backup.stderr)
            restored = self.call("restore", destination, backup.stdout)
            self.assertEqual(restored.returncode, 0, restored.stderr)
            self.assertEqual((destination / "published.json").read_bytes(), b"complete-object")


if __name__ == "__main__":
    unittest.main()
