"""Retain qualified native results and explicitly unqualified shared caches."""
from pathlib import Path
import json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
labels=['native-final','candidate-live-compare','plan-export-final','garage-before-current-finish','closeup-final',
        'shoulder-final','hood-final','fitted-final','modules','physics','wash-final','parser-closeout']
labels += [prefix+renderer for renderer in ['gl_compatibility','mobile']
           for prefix in ['opaque-direct-','app-final-','garage-final-']]
commands={label:json.loads((OUT/(label+'-command.json')).read_text()) for label in labels}
assert all(r['exit_code']==0 for r in commands.values())
corners=json.loads((OUT/'final-corner-check.json').read_text());assert corners['failures']==0
plan=json.loads((OUT/'after-plan-check.json').read_text());assert plan['failures']==0
fences=json.loads((OUT/'direct-render-fences.json').read_text())
assert all(not r['changed'] and r['exit_code']==0 for r in fences.values())
images={str(p.relative_to(OUT)):hashlib.sha256(p.read_bytes()).hexdigest()
        for folder in ['garage-before','garage-final','closeup']
        for p in sorted((OUT/folder).rglob('*.png'))}
(OUT/'comparison-images.json').write_text(json.dumps(images,indent=2))
(OUT/'validation-summary.json').write_text(json.dumps({
    'qualified_commands':commands,'corner_checks':corners['checks'],'corner_failures':corners['failures'],
    'plan_checks':plan['checks'],'plan_failures':plan['failures'],'native_comparison_images':len(images),
    'native_direct_render_fences_stable':True,
    'prepared_live_scope_qualified':False,
    'prepared_final_diagnostic':json.loads((OUT/'prepared-super-current-command.json').read_text()),
    'reason':'Concurrent contour, finish, dependency and Kart writes invalidate prepared-source receipts; preserve all edits',
},indent=2))
shutil.copy2(ROOT/'.tmp/build-cleanup-last.json',OUT/'build-cleanup.json')
print('Qualified native/direct-render receipts saved; live prepared scope explicitly unqualified')
