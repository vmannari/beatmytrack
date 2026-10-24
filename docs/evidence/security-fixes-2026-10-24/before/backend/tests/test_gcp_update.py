"""Retained rollout guards and ordering, without cloud access."""
import importlib.util
import json
import sys
from pathlib import Path
from types import SimpleNamespace

import pytest

directory = Path(__file__).parents[1] / "deploy/gcp"
sys.path.insert(0, str(directory))
spec = importlib.util.spec_from_file_location("bmt_gcp_update_test", directory / "update.py")
update = importlib.util.module_from_spec(spec)
spec.loader.exec_module(update)
sys.path.remove(str(directory))


def test_preview_does_not_construct_cloud_client(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(update, "load_config", lambda path: {"project": "fixture-project", "region": "europe-west1", "owner": "a" * 32})
    monkeypatch.setattr(update.staging, "Staging", lambda *a: pytest.fail("Preview accessed cloud"))
    monkeypatch.setattr(sys, "argv", ["update.py", "--config", str(tmp_path / "config.json")])
    update.main()
    assert json.loads(capsys.readouterr().out)["mode"] == "retained staging update"


def test_disposable_environment_rejected(tmp_path, monkeypatch):
    path = tmp_path / "config.json"
    path.write_text(json.dumps({"expires_at": "2026-10-07T12:00:00+00:00", "retain_data": False}))
    monkeypatch.setattr(update.staging, "validate", lambda *a, **kw: None)
    with pytest.raises(RuntimeError, match="retained"):
        update.load_config(path)


@pytest.mark.parametrize("apply", [False, True])
def test_remote_catalog_program_is_valid_python(apply):
    compile(update.catalog_code(apply), "remote-catalog", "exec")


def test_concurrent_source_change_stops_rollout(monkeypatch):
    updater = object.__new__(update.Updater)
    updater.receipt = {"source_hash": "original"}
    monkeypatch.setattr(update, "source_hash", lambda: "changed")
    with pytest.raises(RuntimeError, match="Source changed"):
        updater.check_source()


@pytest.mark.parametrize("backup_success", [True, False])
def test_backup_and_queue_precede_migration(tmp_path, monkeypatch, backup_success):
    events = []
    names = {key: key for key in ("api", "worker", "migrate", "smoke", "sql", "bucket", "repo")}
    def call(*args):
        events.append(args)
        if args[:3] == ("sql", "backups", "create"):
            return "{}"
        if args[:3] == ("sql", "backups", "list"):
            description = next(x.split("=", 1)[1] for x in events[-2] if x.startswith("--description="))
            return json.dumps([{"description": description, "status": "SUCCESSFUL" if backup_success else "FAILED", "id": "42"}])
        return "{}"
    fake = SimpleNamespace(n=names, preflight=lambda: None, call=call, build=lambda: "new-image", smoke=lambda: None,
        describe=lambda kind, name: {"containers": [{"image": "old-image"}], "settings": {"deletionProtectionEnabled": True}})
    monkeypatch.setattr(update.staging, "Staging", lambda *a: fake)
    monkeypatch.setattr(update, "source_hash", lambda: "stable")
    updater = update.Updater({"owner": "a" * 32, "region": "europe-west1"}, tmp_path)
    (tmp_path / "deployment.json").write_text(json.dumps({"image": "old-image", "url": "https://fixture.run.app"}))
    monkeypatch.setattr(updater, "job_code", lambda code, timeout=900: events.append(("remote-check", code)))
    if not backup_success:
        with pytest.raises(RuntimeError, match="backup"):
            updater.run()
        assert not any(event[:3] == ("run", "jobs", "update") for event in events)
    else:
        updater.run()
        backup = next(i for i, event in enumerate(events) if event[:3] == ("sql", "backups", "create"))
        queue = next(i for i, event in enumerate(events) if event[0] == "remote-check" and "queue_depth" in event[1])
        migration = next(i for i, event in enumerate(events) if event[:4] == ("run", "jobs", "update", "migrate"))
        assert backup < queue < migration
        assert json.loads((tmp_path / "update-receipt.json").read_text())["completed"] is True
