"""Real offline pip hash verification rejects altered artifacts before installation."""
import csv
import hashlib
import importlib.util
import io
import subprocess
import sys
import zipfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("bmt_lock_refresh", ROOT / "backend/deploy/lock_dependencies.py")
refresh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(refresh)


def test_actual_pip_checks_hash_and_rejects_modified_wheel(tmp_path):
    wheel = tmp_path / "bmt_hash_fixture-0.0.0-py3-none-any.whl"
    info = "bmt_hash_fixture-0.0.0.dist-info"
    def write(value):
        files = {"bmt_hash_fixture/__init__.py": "VALUE = " + repr(value) + "\n",
                 info + "/METADATA": "Metadata-Version: 2.1\nName: bmt-hash-fixture\nVersion: 0.0.0\n",
                 info + "/WHEEL": "Wheel-Version: 1.0\nGenerator: BMT regression\nRoot-Is-Purelib: true\nTag: py3-none-any\n"}
        record = io.StringIO()
        writer = csv.writer(record)
        for name in [*files, info + "/RECORD"]:
            writer.writerow([name, "", ""])
        files[info + "/RECORD"] = record.getvalue()
        with zipfile.ZipFile(wheel, "w") as archive:
            for name, content in files.items():
                archive.writestr(name, content)
    write("original")
    digest = hashlib.sha256(wheel.read_bytes()).hexdigest()
    requirements = tmp_path / "requirements.lock"
    requirements.write_text("bmt-hash-fixture==0.0.0 --hash=sha256:" + digest + "\n")
    def install(target):
        return subprocess.run([sys.executable, "-m", "pip", "install", "--no-index", "--no-deps",
                               "--only-binary=:all:", "--require-hashes", "--ignore-installed",
                               "--find-links", str(tmp_path), "--target", str(target), "-r", str(requirements)],
                              capture_output=True, text=True, check=False, timeout=30)
    accepted = install(tmp_path / "accepted")
    assert accepted.returncode == 0, accepted.stdout + accepted.stderr
    assert (tmp_path / "accepted/bmt_hash_fixture/__init__.py").read_text() == "VALUE = 'original'\n"
    write("altered")
    rejected = install(tmp_path / "rejected")
    assert rejected.returncode != 0
    assert "DO NOT MATCH THE HASHES" in rejected.stdout + rejected.stderr
    assert not (tmp_path / "rejected/bmt_hash_fixture").exists()


def test_lock_refresh_reads_current_cross_platform_hash_lock():
    pins = refresh.pinned_versions((ROOT / "backend/requirements.lock").read_text())
    assert pins["cryptography"] == "50.0.2"
    assert pins["setuptools"] == "84.0.0"
    assert len(pins) == 46


@pytest.mark.parametrize("value", ["package>=1.0", "package", "https://untrusted.invalid/pkg.whl",
                                    "package==1.0\nPackage==1.0", "package==1.0\npackage==2.0"])
def test_lock_refresh_refuses_ambiguous_or_unpinned_dependencies(value):
    with pytest.raises(ValueError):
        refresh.pinned_versions(value)
