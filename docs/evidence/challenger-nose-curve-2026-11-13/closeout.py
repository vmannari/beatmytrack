"""Collect final receipts without deleting or staging owner files."""
from pathlib import Path
import hashlib
import json
import shutil

ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
labels=['native-final','plan-export-final','plan-export-baseline','plan-runtime',
        'plan-studio-before-gl','plan-studio-before-mobile',
        'plan-final-gl_compatibility','plan-final-mobile',
        'shoulder-final','hood-final','fitted-final','modules','physics','wash-final','parser-final',
        'opaque-gl_compatibility','opaque-mobile','app-gl_compatibility','app-mobile',
        'garage-gl_compatibility','garage-mobile','garage-before']
commands={label:json.loads((OUT/(label+'-command.json')).read_text()) for label in labels}
assert all(r['exit_code']==0 for r in commands.values())
plan=json.loads((OUT/'after-plan-check.json').read_text());assert plan['failures']==0
baseline=json.loads((OUT/'before-plan-check.json').read_text());assert baseline['failures']>0
transform=json.loads((OUT/'transform-contract.json').read_text())
images={str(p.relative_to(OUT)):hashlib.sha256(p.read_bytes()).hexdigest()
        for folder in ['plan-before','plan-final','garage-before','garage-final']
        for p in sorted((OUT/folder).rglob('*.png'))}
(OUT/'comparison-images.json').write_text(json.dumps(images,indent=2))
(OUT/'validation-summary.json').write_text(json.dumps({
    'qualified_commands':commands,'plan':{k:v for k,v in plan.items() if k!='metrics'},
    'baseline_plan_failures':baseline['failures'],'transform':transform,
    'retained_fixture_timeouts':['plan-before','plan-draft'],
    'initial_scoped_cache_findings':932,'native_comparison_images':len(images),
},indent=2))
shutil.copy2(ROOT/'.tmp/build-cleanup-last.json',OUT/'build-cleanup.json')
(OUT/'fixture-findings.json').write_text(json.dumps({
    'abandoned_showroom_overhead_timeout_seconds':300,
    'abandoned_showroom_labels':['plan-before','plan-draft'],
    'replacement_native_studio_completes_both_renderers':True,
    'initial_optical_probes_used_old_coordinates':{'checks':1840,'failures':4},
    'corrected_optical_probes_keep_coverage_and_facing_thresholds':{'checks':1848,'failures':0},
    'initial_runtime_vector_parameter_precision_failed_1e_10_metre_gate':True,
    'corrected_scalar_parameters_match_to_metres':transform['runtime_offline_max_error_metres'],
},indent=2))
print('Final native, renderer, control and fixture receipts saved')
