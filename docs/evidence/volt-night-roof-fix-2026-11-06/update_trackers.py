"""Record only completed evidence and preserve concurrent tracker contents."""
import json
from pathlib import Path

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
results = {}
for label in ['accepted-compatibility','final-mobile-limited']:
    report = json.loads((evidence/label/'report.json').read_text())
    receipt = json.loads((evidence/(label+'-receipt.json')).read_text())
    if label == 'accepted-compatibility':
        assert report['failures'] == 0 and receipt['exit_code'] == 0
    else:
        assert report['failures'] == 1 and receipt['exit_code'] == 1
        failed = [line for line in (evidence/(label+'.log')).read_text().splitlines() if line.startswith('FAIL:')]
        assert failed == ['FAIL: native controls restore corrected frame']
        assert all(row['restored_roof_changed_pixels'] == 0 and row['after_mean_255'] < row['before_mean_255']*0.4
                   for row in report['metrics'])
    assert receipt['sources_unchanged'] and not receipt['script_errors']
    results[label] = report
assert '468 resources; 1925 checks, 0 failures' in (evidence/'preflight/prepared-preflight.log').read_text()
before = json.loads((evidence/'assets-before.json').read_text())
after = json.loads((evidence/'assets-after.json').read_text())
summary = {'runs':results,'changed_assets':[name for name in before if before[name] != after[name]],
           'unchanged_pictures':[name for name in before if name.endswith('.png') and before[name] == after[name]]}
controls = []
for label in ['final-mobile-pixels','original-mobile-pixels']:
    lines = (evidence/(label+'.log')).read_text().splitlines()
    controls.append(next(line for line in lines if line.startswith('PIXELS full-heading-0 ')))
assert controls[0] == controls[1]
summary['mobile_restoration_control_matches_original'] = True
summary['mobile_restoration_pixels'] = json.loads(controls[0].split(' ',2)[2])
(evidence/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
block = '''<!-- VOLT-NIGHT-ROOF-FIX-20261106 -->
## Volt Night roof reflection corrected after screenshot feedback (2026-11-06)
VNF01-VNF04: Race-owned glass selects a dark Night reflection; daylight/studio and shared Hover defaults retained. Actual Game full/simple/four headings: Compatibility290/0; Mobile290/1 retains a whole-frame mask-restoration mismatch (original-shader control also fails). All16 final roof views, roof restoration, exact day/studio source comparisons and track/state checks pass;116 native captures. Eight bases/200 modules/two Garage templates refresh;468-resource preflight1925/0 and five-picture provenance pass, all five pictures byte-exact to before. Initial access/timeout recovery, comparison identity and rendering-control findings retained without relaxed assertions. [Implementation, before/after views, commands, limits and task-only binary/source checkpoint](LINK). Reload/rebuild and owner/device appearance acceptance remain; no device query/test, APK, owner-save/process change, live/backend request, deployment or main-index write. Concurrent work preserved.
<!-- /VOLT-NIGHT-ROOF-FIX-20261106 -->

'''
for relative in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    path = root/relative
    old = path.read_bytes()
    link = 'VOLT_NIGHT_ROOF_FIX_2026_11_06.md' if relative.startswith('docs/') else 'docs/VOLT_NIGHT_ROOF_FIX_2026_11_06.md'
    prefix = block.replace('LINK',link).encode()
    if old.startswith(prefix): continue
    assert b'<!-- VOLT-NIGHT-ROOF-FIX-20261106 -->' not in old
    path.write_bytes(prefix+old)
print(json.dumps({'checks':[row['checks'] for row in results.values()],
                  'changed_assets':len(summary['changed_assets']),'unchanged_pictures':len(summary['unchanged_pictures'])}))
