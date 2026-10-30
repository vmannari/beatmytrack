"""Independent local server verification of the actual forklift-4 five-lap run."""
import json
from pathlib import Path
import sys
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'backend'))
from bmt_backend.runs import board_manifest
from bmt_backend.track_models import digest
from bmt_backend.verifier import GodotVerifier

generated = json.loads((OUT / 'canonical-race.json').read_text())
assert generated['ok']
race = generated['result']
assert race['vehicle_id'] == 'forklift'
old = json.loads((OUT / 'before/backend__tests__fixtures__verified_oval.json').read_text())['expected_manifest']
expected_hash = json.loads((OUT / 'turning.json').read_text())['measurements']['config_hash']
verifier = GodotVerifier(SimpleNamespace(
    godot_bin=r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',
    game_project=ROOT / 'game', verifier_timeout_seconds=120,
))
try:
    result = verifier.verify_canonical_diagnostic(race['document'], race['replay'], 'forklift')
    assert result['time_ticks'] == race['time_ticks'] and len(result['lap_ticks']) == 5
    manifest = result['manifest']
    current = manifest['vehicles']['forklift']
    assert current == {'handling_version': 'forklift-4', 'config_hash': expected_hash}
    for vehicle in manifest['vehicles']:
        if vehicle != 'forklift':
            assert old['vehicles'][vehicle] == manifest['vehicles'][vehicle], vehicle
    assert old['physics_version'] == manifest['physics_version']
    old_same_track = {**manifest, 'vehicles': {**manifest['vehicles'], 'forklift': old['vehicles']['forklift']}}
    old_board = digest(board_manifest(SimpleNamespace(manifest=old_same_track), 'forklift'))
    new_board = digest(board_manifest(SimpleNamespace(manifest=manifest), 'forklift'))
    assert old_board != new_board
    fixture = json.loads((ROOT / 'backend/tests/fixtures/verified_oval.json').read_text())
    assert fixture['expected_manifest']['vehicles']['forklift'] == current
    receipt = {'inputs': len(race['replay']['frames']), 'time_ticks': result['time_ticks'], 'time_ms': result['time_ms'], 'lap_ticks': result['lap_ticks'], 'forklift': current, 'physics_version': manifest['physics_version'], 'six_other_car_entries_unchanged': True, 'old_same_track_board': old_board, 'new_board': new_board}
    (OUT / 'canonical-verification.json').write_text(json.dumps(receipt, indent=2) + '\n', encoding='utf-8')
    print('FORKLIFT_TURNING_VERIFIER:', json.dumps(receipt))
finally:
    verifier.close()
