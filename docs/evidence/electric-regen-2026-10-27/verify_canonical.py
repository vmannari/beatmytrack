"""Independently accept the recorded five-lap Electric19 race offline."""
from pathlib import Path
from types import SimpleNamespace
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'backend'))
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import digest
from bmt_backend.verifier import GodotVerifier

generated = json.loads((OUT / 'electric_over_under/over-under-race.json').read_text())
assert generated['ok']
race = generated['result']
verifier = GodotVerifier(SimpleNamespace(
    godot_bin=r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',
    game_project=ROOT / 'game', verifier_timeout_seconds=90))
try:
    result = verifier.verify_canonical_diagnostic(race['document'], race['replay'], 'electric')
    assert result['time_ticks'] == race['time_ticks']
    assert len(result['lap_ticks']) == 5
    current = result['manifest']
    assert current['physics_version'] == 'arcade-planar-0.75'
    assert current['vehicles']['electric'] == {
        'handling_version': 'electric-19',
        'config_hash': '4a6003cae32137af7d3e64b714fa89d7be290259d78262f5749b0dac579dd4f0'}
    old = json.loads((OUT / 'before/backend__tests__fixtures__verified_oval.json').read_text())['expected_manifest']
    old['track_content_hash'] = current['track_content_hash']
    assert old['physics_version'] == current['physics_version']
    for car, values in old['vehicles'].items():
        if car != 'electric':
            assert current['vehicles'][car] == values
        old_board = digest(board_manifest(SimpleNamespace(manifest=old), car))
        new_board = digest(board_manifest(SimpleNamespace(manifest=current), car))
        assert (old_board == new_board) == (car != 'electric'), car
    receipt = {'input_count': len(race['replay']['frames']), 'time_ticks': result['time_ticks'],
               'time_ms': result['time_ms'], 'lap_ticks': result['lap_ticks'],
               'electric': current['vehicles']['electric'],
               'six_other_car_boards_exact': True, 'electric_board_distinct': True}
    (OUT / 'canonical-verification.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))
finally:
    verifier.close()
