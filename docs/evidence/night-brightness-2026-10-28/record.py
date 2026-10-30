"""Record the scoped Night change and validate a source-only checkpoint."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
runtime = 'game/track/track_theme.gd'
helper = 'game/tests/review_night_brightness.gd'
before = (OUT / 'before/track_theme.gd.txt').read_text(encoding='utf-8')
after = (ROOT / runtime).read_text(encoding='utf-8')
expected = before.replace(
    '\tenvironment.ambient_light_energy = 0.045 if night else 0.35',
    '\t# Lift unlit roads slightly for phone/tablet readability; lamps still dominate.\n'
    '\tenvironment.ambient_light_energy = 0.065 if night else 0.35',
).replace('0.025 if night else 0.50', '0.035 if night else 0.50')
assert after == expected, 'Runtime scope differs from the two Night values and comment'
patch = ''.join(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                    fromfile='a/' + runtime, tofile='b/' + runtime))
patch += ''.join(difflib.unified_diff([], (ROOT / helper).read_text(encoding='utf-8').splitlines(True),
                                     fromfile='/dev/null', tofile='b/' + helper))
(OUT / 'source.patch').write_text(patch, encoding='utf-8', newline='\n')
checkpoint = ROOT / 'tmp/night-brightness-checkpoint'
baseline = checkpoint / runtime
baseline.parent.mkdir(parents=True, exist_ok=True)
baseline.write_text(before, encoding='utf-8', newline='\n')
checks = []
for args in [
    ['git','apply','--reverse','--check',str(OUT / 'source.patch')],
    ['git','apply','--check','--directory=tmp/night-brightness-checkpoint',str(OUT / 'source.patch')],
    ['git','apply','--check','--whitespace=error-all','--directory=tmp/night-brightness-checkpoint',str(OUT / 'source.patch')],
]:
    result = subprocess.run(args, cwd=ROOT, capture_output=True, text=True)
    checks.append({'command':args,'exit_code':result.returncode,'output':result.stdout+result.stderr})
    assert result.returncode == 0, checks[-1]
captures = {renderer:json.loads((OUT / renderer / 'capture.json').read_text(encoding='utf-8'))
            for renderer in ['gl_compatibility','mobile']}
assert all(not row['failed'] and len(row['views']) == 8 for row in captures.values())
logs = list((OUT / 'logs').glob('*test-script.log'))
assert any('NIGHT_LIGHTING: 15 checks, 0 failures' in path.read_text(encoding='utf-8') for path in logs)
files = [ROOT/runtime, ROOT/helper, OUT/'run.ps1', OUT/'record.py', OUT/'source.patch']
files += sorted(OUT.glob('*/*.png'))
report = {
    'requirements':['NBR01','NBR02','NBR-Q01','NBR-R01'],
    'runtime_scope_exact':True,
    'night_ambient_energy':{'before':0.045,'after':0.065},
    'night_moonlight_energy':{'before':0.025,'after':0.035},
    'existing_lighting_checks':15,'existing_lighting_failures':0,
    'captures':captures,'checkpoint_checks':checks,
    'files_sha256':{str(path.relative_to(ROOT)).replace('\\','/'):hashlib.sha256(path.read_bytes()).hexdigest() for path in files},
    'retained_findings':['Initial host script execution policy refusal',
                         'Restricted engine log and certificate-store access failures',
                         'Initial native helper with disposable records hit concurrent cosmetic typed-array error; final helper uses no records'],
    'limits':['Desktop renderers only; no physical-device query or test',
              'Reload/rebuild and owner phone/tablet visual acceptance remain',
              'Concurrent sources and generated metadata excluded from scoped patch',
              'No APK, deployment, live writes, owner-process restart or main-index changes'],
}
(OUT/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('NIGHT_BRIGHTNESS: exact scope; 15 lighting checks; 16 native captures; forward/reverse/whitespace checkpoint checks pass')
