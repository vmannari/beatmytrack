from pathlib import Path
from types import SimpleNamespace
import json
import sys
import os

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
os.environ.update(APPDATA=str(ROOT/'tmp/electric-stronger-drift-verify'),LOCALAPPDATA=str(ROOT/'tmp/electric-stronger-drift-verify/local'),BMT_API_URL='',BMT_DEV_AUTH_KEY='')
sys.path.insert(0, str(ROOT / 'backend'))
from bmt_backend.verifier import GodotVerifier

race = json.loads((OUT / 'driving/over-under-race.json').read_text())['result']
verifier = GodotVerifier(SimpleNamespace(
    godot_bin=r'C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe',
    game_project=ROOT / 'game', verifier_timeout_seconds=90))
try:
    result = verifier.verify_canonical_diagnostic(race['document'], race['replay'], 'electric')
    assert result['time_ticks'] == race['time_ticks']
    assert len(result['lap_ticks']) == 5
    expected=json.loads((OUT/'drift/power-increment.json').read_text())['metrics']['electric']
    assert result['manifest']['vehicles']['electric'] == expected
    old = json.loads((OUT / 'before-manifest.json').read_text())
    absent = []
    for car, values in old['vehicles'].items():
        if car != 'electric':
            if car not in result['manifest']['vehicles']:
                absent.append(car)
                continue
            assert result['manifest']['vehicles'][car] == values
    receipt = {'input_count': len(race['replay']['frames']), 'time_ticks': result['time_ticks'],
               'time_ms': result['time_ms'], 'lap_ticks': result['lap_ticks'],
               'electric': result['manifest']['vehicles']['electric'],
               'present_other_car_contracts_exact': True,
               'absent_from_concurrent_catalogue': absent}
    (OUT / 'canonical-verification.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt))
finally:
    verifier.close()
