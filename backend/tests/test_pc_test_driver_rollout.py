"""The local opt-in reaches WSL and backs up existing data before migration."""

import importlib.util
from pathlib import Path
from types import SimpleNamespace

import pytest

ROOT = Path(__file__).resolve().parents[2]


@pytest.fixture
def launcher():
    spec = importlib.util.spec_from_file_location("pc_launcher", ROOT / "backend/deploy/pc_development.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_local_opt_in_preserves_credentials_and_survives_restart(launcher, tmp_path, monkeypatch):
    path = tmp_path / "pc.env"
    original = "# private local config\nBMT_DEV_AUTH_KEY=test-key-preserved\nBMT_DB_PASSWORD=also-preserved\nBMT_TEST_DRIVERS_ENABLED=false\n"
    path.write_text(original)
    monkeypatch.setattr(launcher, "ENV_FILE", path)
    config = {"BMT_DEV_AUTH_KEY": "test-key-preserved", "BMT_DB_PASSWORD": "also-preserved"}
    launcher.enable_test_drivers(config)
    launcher.enable_test_drivers(config)
    result = path.read_text()
    assert "BMT_DEV_AUTH_KEY=test-key-preserved" in result
    assert "BMT_DB_PASSWORD=also-preserved" in result
    assert result.count("BMT_TEST_DRIVERS_ENABLED=") == 1
    assert "BMT_TEST_DRIVERS_ENABLED=true" in result
    assert config["BMT_TEST_DRIVERS_ENABLED"] == "true"


def test_backup_quiesces_writers_before_copy_and_records_checksums(launcher, tmp_path, monkeypatch):
    calls = []

    def execute(command, **kwargs):
        calls.append(command)
        if "--services" in command:
            return SimpleNamespace(stdout="db\napi\nworker\n")
        if "stdout" in kwargs:
            kwargs["stdout"].write(b"logical data fixture")
        return SimpleNamespace(stdout="")

    monkeypatch.setattr(launcher, "ROOT", tmp_path)
    monkeypatch.setattr(launcher.subprocess, "run", execute)
    destination = launcher.backup_local_data(["compose"])
    assert calls[1] == ["compose", "stop", "api", "worker"]
    assert "pg_dump" in calls[2] and "objects.tar" not in calls[2]
    assert (destination / "database.dump").read_bytes() == b"logical data fixture"
    assert (destination / "objects.tar").read_bytes() == b"logical data fixture"
    assert len((destination / "SHA256SUMS").read_text().splitlines()) == 2
    assert (destination / "COMPLETE").is_file()


def test_wsl_receives_nonsecret_flag_before_any_migration(launcher, tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(launcher.sys, "platform", "win32")
    monkeypatch.setattr(launcher.sys, "argv", ["pc_development.py", "start", "--test-drivers"])
    monkeypatch.setattr(launcher, "local_configuration", lambda: {"BMT_DEV_AUTH_KEY": "private-test-key"})
    monkeypatch.setattr(launcher, "enable_test_drivers", lambda config: calls.append("enable"))
    monkeypatch.setattr(launcher, "backup_local_data", lambda command: calls.append("backup"))

    def execute(command, **kwargs):
        assert command[:7] == ["wsl", "-d", "Ubuntu", "--", "env", "BMT_TEST_DRIVERS_ENABLED=true", "docker"]
        assert "private-test-key" not in command
        calls.append(command)
        if "exec" in command:
            return SimpleNamespace(stdout='{"manifest":"test"}')
        return SimpleNamespace(stdout="")

    monkeypatch.setattr(launcher.subprocess, "run", execute)

    class Response:
        def __enter__(self):
            return self

        def __exit__(self, *args):
            pass

        def read(self):
            return b'{"manifest":"test"}'

    monkeypatch.setattr(launcher.urllib.request, "urlopen", lambda *args, **kwargs: Response())
    monkeypatch.setattr(launcher, "configure_game", lambda config: calls.append("configure"))
    launcher.main()
    assert calls[0] == "enable" and calls[3] == "backup"
    assert calls[1][-2:] == ["build", "api"]
    assert calls[2][-6:] == ["up", "-d", "--wait", "--wait-timeout", "90", "db"]
    assert calls[4][-5:] == ["run", "--rm", "--no-deps", "-T", "migrate"]
    assert calls[5][-5:] == ["up", "-d", "--wait", "--wait-timeout", "90"]
