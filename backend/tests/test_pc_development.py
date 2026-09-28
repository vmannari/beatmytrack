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
