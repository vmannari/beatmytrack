"""Verify completed receipts, controlled startup contrast and current delivery."""
import hashlib
import json
from pathlib import Path
import re
import statistics

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
PROFILES = ['frozen-before-custom-1','frozen-after-custom-1','frozen-after-custom-2','frozen-before-custom-2','frozen-before-stock','frozen-after-stock','frozen-after-disk-hit']
TESTS = {'frozen-contract-headless':19,'frozen-contract-compatibility':43,'frozen-contract-mobile':43,
         'frozen-shell':22,'frozen-header-compatibility':26,'final-header-mobile':26,'final-fences':19,'frozen-before-shell':22,
         'final-shell-verbose':22,'baseline-shell-verbose':22}
rows = []
for name in PROFILES+list(TESTS):
    row = json.loads((OUT/name/'run.json').read_text())
    assert row['exit_code']==0 and not row['timeout'] and not row['script_error'] and not row['source_changes'],row
    assert row['version']==(ROOT/'godot-version.txt').read_text().strip()
    result_path = OUT/name/'result.json'
    if name in TESTS:
        if result_path.exists():
            result = json.loads(result_path.read_text())
            assert result['checks']==TESTS[name] and result['failures']==0,(name,result)
        else:
            assert re.search(rf'{TESTS[name]} checks[ ,]+0 failures',(OUT/name/'run.log').read_text()),name
    rows.append(row)
before = [json.loads((OUT/name/'result.json').read_text()) for name in ['frozen-before-custom-1','frozen-before-custom-2']]
after = [json.loads((OUT/name/'result.json').read_text()) for name in ['frozen-after-custom-1','frozen-after-custom-2']]
for row in before:
    assert row['header_captures']==1 and row['peak_worlds']==1 and row['io_drained']
for row in after:
    assert row['header_captures']==0 and row['settled_captures']==0 and row['peak_worlds']==0 and row['io_drained']
hit = json.loads((OUT/'frozen-after-disk-hit/result.json').read_text())
assert hit['settled_disk_hits']==1 and hit['settled_captures']==0 and hit['peak_worlds']==0
for name in PROFILES:
    row = json.loads((OUT/name/'result.json').read_text())
    assert row['network_disabled'] and row['screen']=='account' and not row['feature_resources']
for name in ['frozen-contract-compatibility','frozen-contract-mobile']:
    row = json.loads((OUT/name/'result.json').read_text())
    assert row['captures']==1 and row['disk_hits']==3 and row['peak_worlds']==1 and row['cover_starts']==2
    for view in ['menu-silhouette','garage-cover','garage-ready']:
        assert (OUT/name/(view+'.png')).stat().st_size>10000
for name in ['frozen-header-compatibility','final-header-mobile']:
    row = json.loads((OUT/name/'result.json').read_text())
    assert len(row['rows'])==5
    for car in row['rows']:
        assert car['same_frame_exact'] and car['appearance_difference']<0.02
diagnostics_before = json.loads((OUT/'frozen-before-shell/run.json').read_text())['diagnostics']
diagnostics_after = json.loads((OUT/'frozen-shell/run.json').read_text())['diagnostics']
verbose_log = (OUT/'final-shell-verbose/run.log').read_text()
assert 'AudioStreamMP3' in verbose_log and 'AudioStreamPlaybackMP3' in verbose_log
files = ['game/core/app.gd','game/ui/header_car_appearance_cache.gd','game/ui/profile_car.gd',
         'game/tests/profile_deferred_header.gd','game/tests/test_deferred_header.gd','game/tests/test_header_capture_fences.gd']
hashes = {}
for relative in files:
    actual = (ROOT/relative).read_bytes()
    assert actual==(OUT/'after'/relative).read_bytes(),relative
    hashes[relative] = hashlib.sha256(actual).hexdigest()
old = statistics.median(row['engine_to_menu_ms'] for row in before)
new = statistics.median(row['engine_to_menu_ms'] for row in after)
summary = dict(accepted_runs=len(rows),primary_candidate_assertions=198,candidate_diagnostic_assertions=22,baseline_assertions=44,failures=0,
               before_custom_ms=[row['engine_to_menu_ms'] for row in before],after_custom_ms=[row['engine_to_menu_ms'] for row in after],
               before_median_ms=old,after_median_ms=new,reduction_ms=old-new,reduction_percent=100*(old-new)/old,
               desktop_only=True,phone_tested=False,shader_changes=False,delivery_sha256=hashes,shell_diagnostics=diagnostics_after,baseline_shell_diagnostics=diagnostics_before)
(OUT/'validation.json').write_bytes((json.dumps(summary,indent=2)+'\n').encode('utf-8'))
print(json.dumps(summary))
