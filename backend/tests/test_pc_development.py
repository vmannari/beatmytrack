import importlib.util
from pathlib import Path

import pytest


@pytest.fixture
def launcher(tmp_path, monkeypatch):
    path = Path(__file__).resolve().parents[1] / "deploy" / "pc_development.py"
    spec = importlib.util.spec_from_file_location("pc_development", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, "ENV_FILE", tmp_path / "private" / "pc.env")
    monkeypatch.setenv("APPDATA", str(tmp_path / "appdata"))
    return module


def test_local_setup_preserves_generated_identity_key(launcher):
    first = launcher.local_configuration()
    assert len(first["BMT_DEV_AUTH_KEY"]) >= 32
    assert launcher.local_configuration() == first
    assert not first["BMT_GOOGLE_WEB_CLIENT_ID"]


def test_normal_editor_launch_gets_same_key(launcher, tmp_path):
    config = launcher.local_configuration()
    launcher.configure_game(config)
    target = tmp_path / "appdata" / "Circuit01Lab" / "backend.cfg"
    assert launcher.URL in target.read_text()
    assert config["BMT_DEV_AUTH_KEY"] in target.read_text()
    original = target.read_bytes()
    launcher.configure_game(config)
    assert target.read_bytes() == original


def test_external_game_configuration_not_overwritten(launcher, tmp_path):
    target = tmp_path / "appdata" / "Circuit01Lab" / "backend.cfg"
    target.parent.mkdir(parents=True)
    target.write_text('[backend]\nurl="https://existing.example"\n')
    before = target.read_bytes()
    with pytest.raises(RuntimeError, match="another backend"):
        launcher.configure_game(launcher.local_configuration())
    assert target.read_bytes() == before


def test_start_builds_verified_image_before_replacing_services(launcher, monkeypatch):
    commands = []
    monkeypatch.setattr(launcher.sys, "argv", ["pc_development.py", "start"])
    monkeypatch.setattr(launcher.sys, "platform", "win32")
    monkeypatch.setattr(launcher.subprocess, "run", lambda args, **kwargs: commands.append(args))
    launcher.main()
    assert commands[0][-2:] == ["build", "api"]
    assert commands[1][-5:] == ["up", "-d", "--wait", "--wait-timeout", "90"]


def test_failed_image_build_leaves_running_backend_untouched(launcher, monkeypatch):
    commands = []
    monkeypatch.setattr(launcher.sys, "argv", ["pc_development.py", "start"])
    monkeypatch.setattr(launcher.sys, "platform", "win32")

    def fail(args, **kwargs):
        commands.append(args)
        raise launcher.subprocess.CalledProcessError(1, args)

    monkeypatch.setattr(launcher.subprocess, "run", fail)
    with pytest.raises(launcher.subprocess.CalledProcessError):
        launcher.main()
    assert len(commands) == 1 and commands[0][-2:] == ["build", "api"]
