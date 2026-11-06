"""Validate review evidence, without rerunning or altering the application."""
import ast
import json
from pathlib import Path
import re

folder = Path(__file__).resolve().parent
ast.parse((folder / 'run_review.py').read_text(encoding='utf-8'))
runs = json.loads((folder / 'runs.json').read_text())
assert len(runs) == 7
assert all(row['exit_code'] == 0 and not row['timeout'] and not row['source_changes'] and not row['script_or_shader_error'] for row in runs)
before = json.loads((folder / 'sources-before.json').read_text())
after = json.loads((folder / 'sources-after.json').read_text())
assert before and before == after
counts = []
for row in runs:
    for line in row['result_lines']:
        match = re.search(r': (\d+) checks, (\d+) failures$', line)
        if match:
            assert int(match[1]) > 0 and int(match[2]) == 0
            counts.append(int(match[1]))
assert counts == [146, 631, 9, 16], counts
startup = {}
for name in ['startup-stock', 'startup-custom-miss', 'startup-custom-hit']:
    value = json.loads((folder / name / 'startup.json').read_text())
    assert value['network_disabled'] and value['header_writes_drained']
    assert value['initial_menu_drawn'] and value['screen'] == 'account'
    startup[name] = value
assert startup['startup-custom-miss']['header_captures'] == 1
assert startup['startup-custom-hit']['header_captures'] == 0
assert startup['startup-custom-hit']['header_disk_hits'] == 1
race = json.loads((folder / 'race-pine-winter/profile.json').read_text())
assert race['checks'] == 16 and race['failures'] == 0 and len(race['rows']) == 4
assert [(r['theme'], r['cycle']) for r in race['rows']] == [('pine', 0), ('pine', 1), ('winter', 0), ('winter', 1)]
assert all(r['wall_us'] > 0 and r['max_frame_ms'] > 0 for r in race['rows'])
assert len(list((folder / 'race-pine-winter').glob('*.png'))) == 4
summary = {'runs': len(runs), 'assertions': sum(counts), 'failures': 0,
           'source_files_unchanged': len(before), 'startup_cases': len(startup),
           'race_entries': len(race['rows']), 'device_test_performed': False,
           'scope': 'Current source checks and Windows desktop observations; no Android performance certification',
           'diagnostics': 'All seven logs retain the offline Windows root-certificate-store error.'}
(folder / 'validation.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
print(json.dumps(summary))
