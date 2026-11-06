"""Validate actual receipts, image persistence and the final frozen runtime."""
import hashlib
import json
from pathlib import Path

out = Path(__file__).resolve().parent
root = out.parents[2]
project = Path(json.loads((out/'frozen-project.json').read_text())['project'])
runs = ['before-idle', 'after-idle-final', 'picker-settled', 'cached-restart',
        'final-fences', 'final-shell', 'final-deferred', 'final-warm', 'final-drive']
receipts = {}
for name in runs:
    row = json.loads((out/name/'run.json').read_text())
    assert row['exit_code']==0 and not row['timeout'] and not row['script_error'], name
    assert not row['source_changes'], name
    assert all('Failed to read the root certificate store' in text for text in row['diagnostics']), (name,row['diagnostics'])
    receipts[name] = row['results']
    result = out/name/'result.json'
    if result.exists(): assert json.loads(result.read_text()).get('failures',0)==0, name
entry = json.loads((out/'entry-run.json').read_text())
assert entry['exit_code']==0
entry_result = json.loads((out/'entry-result.json').read_text())
assert entry_result==dict(checks=30,failures=0)
first = (out/'picker-settled/header.png').read_bytes()
reloaded = (out/'cached-restart/header.png').read_bytes()
assert first==reloaded
restart = json.loads((out/'cached-restart/result.json').read_text())
assert restart['captures']==0 and restart['disk_hits']==5 and restart['idle_garage_prepared']
runtime = ['game/core/app.gd','game/core/features/garage.gd','game/ui/header_car_appearance_cache.gd',
           'game/ui/garage_preloader.gd','game/ui/garage_preloaded_studio.gd']
hashes = {}
for relative in runtime:
    data = (root/relative).read_bytes()
    assert data==(project.parent/relative).read_bytes(), relative
    hashes[relative] = hashlib.sha256(data).hexdigest()
report = dict(accepted_runs=receipts, normal_entry=entry_result,
    header_png_restart_byte_exact=True, final_runtime_sha256=hashes,
    build_identity_checks=33, device_test=False, main_index_written=False)
(out/'validation.json').write_bytes((json.dumps(report,indent=2)+'\n').encode('utf-8'))
print(json.dumps(dict(accepted_runs=len(runs),normal_entry=entry_result,header_png_restart_byte_exact=True)))
