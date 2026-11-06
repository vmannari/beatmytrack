"""Install the final extra shadow guard after the native suite, then prove parity."""
import json,shutil,subprocess,sys
from pathlib import Path
p=Path(__file__).resolve().parent
root=p.parents[2]
game=Path(json.loads((p/'frozen-project.json').read_text())['project'])
suite=json.loads((p/'final-suite.json').read_text())
assert len(suite)==8 and all(row['exit_code']==0 for row in suite)
reference=p/'harness/validated_pruning.gd.txt'
if not reference.exists(): shutil.copyfile(game/'track/surface_shader_pruning.gd',reference)
shutil.copyfile(reference,game/'tests/fixtures/first_use_validated_pruning.gd.txt')
for name in ('track/surface_shader_pruning.gd','tests/test_surface_shader_pruning.gd'):
    shutil.copyfile(root/'game'/name,game/name)
shutil.copyfile(p/'harness/verify_final_pruning.gd',game/'tests/verify_final_pruning.gd')
rows=[]
for label,script,extra in [
    ('final-contract','test_surface_shader_pruning.gd',['--headless']),
    ('final-source-parity','verify_final_pruning.gd',['--headless']),
    ('first-laps-gl-fixed','test_shared_graphics_first_laps.gd',['--first-emission']),
    ('first-laps-mobile-fixed','test_shared_graphics_first_laps.gd',['--renderer','mobile','--first-emission']),
    ('final-fresh-abba','profile_first_use_comparison.gd',[]),
]:
    command=[sys.executable,str(p/'run_check.py'),label,'res://tests/'+script,'--frozen','--timeout','420' if 'first-laps' in label else '180',*extra]
    print('RUN',label,flush=True)
    code=subprocess.run(command).returncode
    rows.append(dict(label=label,exit_code=code,command=command))
    (p/'final-hardening.json').write_text(json.dumps(rows,indent=2)+'\n')
    if code: sys.exit(code)
