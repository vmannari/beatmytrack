"""POSIX helper fault tests; every Docker invocation targets a local mock."""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

MOCK_DOCKER = """#!/bin/sh
set -eu
printf '%s\\n' "$*" >> "$BMT_MOCK_LOG"
case "$*" in
    *'ps --status running --services'*)
        test "$BMT_MOCK_FAILURE" != ps || exit 17
        printf 'api\\nworker\\n';;
    *'backup_guard begin'*)
        test "$BMT_MOCK_FAILURE" != begin || exit 17
        printf '00000000000000000000000000000000';;
    *'backup_guard end --token '*)
        test "$BMT_MOCK_FAILURE" != end || exit 17;;
    *'pg_dump '*)
        test "$BMT_MOCK_FAILURE" != dump || exit 17
        printf 'synthetic-database-dump';;
    *'object_archive.py archive'*)
        test "$BMT_MOCK_FAILURE" != archive || exit 17
        printf 'synthetic-object-archive';;
    *'ps -q db'*) printf 'synthetic-container';;
    'inspect '*) printf 'bmt-backup-test';;
    *'start worker'*) test "$BMT_MOCK_FAILURE" != restart || exit 17;;
esac
"""


@unittest.skipUnless(os.name == "posix" and shutil.which("sh"), "POSIX helper")
class BackupWrapperTests(unittest.TestCase):
    def run_backup(self, failure="", *, mode="online", cloud=False):
        with tempfile.TemporaryDirectory(prefix="bmt-backup-helper-") as directory:
            root = Path(directory)
            source = Path(__file__).resolve().parent
            for name in ("backup.sh", "common.sh"):
                shutil.copyfile(source / name, root / name)
            (root / ".env").write_text("# synthetic mock only\n")
            binary = root / "bin"
            binary.mkdir()
            mock = binary / "docker"
            mock.write_text(MOCK_DOCKER)
            mock.chmod(0o700)
            log = root / "docker.log"
            destination = root / "new-backup"
            env = os.environ | {
                "PATH": str(binary) + os.pathsep + os.environ["PATH"],
                "BMT_ENV_FILE": str(root / ".env"),
                "BMT_BACKUP_MODE": mode,
                "BMT_COMPOSE_CLOUD": "1" if cloud else "0",
                "BMT_COMPOSE_PROJECT": "bmt-backup-test",
                "BMT_MOCK_LOG": str(log),
                "BMT_MOCK_FAILURE": failure,
            }
            result = subprocess.run(
                ["sh", str(root / "backup.sh"), str(destination)],
                cwd=root,
                env=env,
                capture_output=True,
                text=True,
                timeout=10,
                check=False,
            )
            calls = log.read_text().splitlines()
            files = {p.name: p.read_bytes() for p in destination.iterdir()}
            self.assertFalse((root / ".backup.lock").exists(), result.stderr)
            return result, calls, files

    def test_online_completion_follows_guard_release_without_stopping_writers(self):
        result, calls, files = self.run_backup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("COMPLETE", files)
        self.assertIn("GC_RECOVERY_TOKEN", files)
        names = "\n".join(calls)
        self.assertLess(names.index("backup_guard begin"), names.index("pg_dump"))
        self.assertLess(names.index("object_archive.py"), names.index("backup_guard end"))
        self.assertNotIn(" stop ", names)
        self.assertNotIn(" start ", names)
        self.assertIn("Backup completed", result.stdout)

    def test_failures_remove_lock_and_never_publish_completion(self):
        for failure in ("ps", "begin", "dump", "archive", "end"):
            with self.subTest(failure=failure):
                result, calls, files = self.run_backup(failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("COMPLETE", files)
                self.assertNotIn("Backup completed", result.stdout)
                released = any("backup_guard end" in call for call in calls)
                self.assertEqual(released, failure in ("dump", "archive", "end"))
                if failure == "end":
                    self.assertIn("GC_RECOVERY_TOKEN", files)

    def test_offline_restarts_previous_writers_and_marks_restart_failure(self):
        for failure in ("", "dump", "restart"):
            with self.subTest(failure=failure):
                result, calls, files = self.run_backup(failure, mode="offline")
                names = "\n".join(calls)
                self.assertIn(" stop api worker", names)
                self.assertIn(" start api", names)
                self.assertIn(" start worker", names)
                self.assertNotIn("backup_guard", names)
                self.assertEqual(result.returncode == 0, not failure)
                self.assertEqual("COMPLETE" in files, not failure)

    def test_cloud_helper_preserves_override_and_project_on_every_call(self):
        result, calls, _ = self.run_backup(cloud=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        for call in calls:
            if call.startswith("compose "):
                self.assertIn("compose.cloud.yaml", call)
                self.assertIn("-p bmt-backup-test", call)


if __name__ == "__main__":
    unittest.main()
