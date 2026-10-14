"""Dependency updates respect the canonical distribution name, without network."""
import importlib.util
import json
import sys
from pathlib import Path

import pytest

spec = importlib.util.spec_from_file_location("bmt_lock_followup", Path(__file__).parents[1] / "deploy/lock_dependencies.py")
lock = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lock)


def test_case_alias_replaces_existing_version_without_duplicate(tmp_path, monkeypatch):
    path = tmp_path / "requirements.lock"
    path.write_text("CacheControl==0.14.4\n")
    receipt = tmp_path / "receipt.json"
    def fake(name, version, _context):
        return {"name": name, "version": version, "wheels": [{"filename": "fixture.whl", "sha256": "a" * 64}]}
    monkeypatch.setattr(lock, "metadata", fake)
    monkeypatch.setattr(sys, "argv", ["lock_dependencies.py", "--lock", str(path), "--add", "cachecontrol==0.14.5", "--receipt", str(receipt)])
    lock.main()
    pins = lock.pinned_versions(path.read_text())
    assert len(pins) == 1 and list(pins.values()) == ["0.14.5"]
    assert len(json.loads(receipt.read_text())) == 1


@pytest.mark.parametrize("value", ["some.pkg==1\nsome-pkg==2", "some__pkg==1\nsome-pkg==2", "some.-_pkg==1\nsome-pkg==2"])
def test_all_pep503_alias_duplicates_are_rejected(value):
    with pytest.raises(ValueError, match="Duplicate"):
        lock.pinned_versions(value)


@pytest.mark.parametrize("value", ["package.==1", "package-==1", "package_==1"])
def test_invalid_distribution_names_are_rejected(value):
    with pytest.raises(ValueError):
        lock.pinned_versions(value)
