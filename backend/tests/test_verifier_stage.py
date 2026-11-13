"""The stripped verifier must contain every statically preloaded dependency."""
import importlib.util
import re
from pathlib import Path


def test_staged_verifier_has_checkpoint_cache_and_closed_preloads(tmp_path):
    root = Path(__file__).resolve().parents[2]
    spec = importlib.util.spec_from_file_location('stage_under_test', root / 'backend/deploy/stage_verifier.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    game = tmp_path / 'game'
    module.stage(root, game)
    cache = 'race/checkpoint_layout_cache.gd'
    assert (game / cache).read_bytes() == (root / 'game' / cache).read_bytes()
    missing = []
    for script in game.rglob('*.gd'):
        for dependency in re.findall(r'preload\([\"\']res://([^\"\']+)[\"\']\)', script.read_text(encoding='utf-8')):
            if not (game / dependency).is_file():
                missing.append((script.relative_to(game).as_posix(), dependency))
    assert not missing, missing
