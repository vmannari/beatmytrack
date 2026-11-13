"""Serial, quiet final timing matrix. Run before starting engine compilation."""
import json
from pathlib import Path
import shutil
import subprocess
import sys

out = Path(__file__).resolve().parent
root = out.parents[2]
baseline = Path(json.loads((out/'baseline-project.json').read_text())['project'])
startup = Path(json.loads((out/'startup/frozen-candidate.json').read_text())['project'])
final = Path(json.loads((out/'frozen-project.json').read_text())['project'])
shutil.copyfile(out/'frozen-project.json', out/'final-project.json')
# Observation-only files: the original App still builds the original podium.
for relative in ['tests/profile_podium_loading_half.gd','ui/rivalry_podium_pictures.gd']:
    shutil.copyfile(root/'game'/relative, baseline/relative)
cases = [
    ('final-menus-control',baseline,'profile_podium_loading_half.gd','combined-menu-pair',[]),
    ('final-menus-candidate',final,'profile_podium_loading_half.gd','combined-menu-pair',[]),
    ('final-podium-hit-a',final,'profile_podium_loading_half.gd','combined-menu-pair',['--pages=rivalry']),
    ('final-podium-control',baseline,'profile_podium_loading_half.gd','combined-menu-pair',['--pages=rivalry']),
    ('final-podium-hit-b',final,'profile_podium_loading_half.gd','combined-menu-pair',['--pages=rivalry']),
    ('startup-control-e',baseline,'profile_startup_shell.gd',None,[]),
    ('startup-final-e',startup,'profile_startup_shell.gd',None,[]),
    ('startup-control-f',baseline,'profile_startup_shell.gd',None,[]),
    ('startup-final-f',startup,'profile_startup_shell.gd',None,[]),
    ('startup-owner-accepted-native',startup,'test_startup_selected_owner.gd',None,[]),
]
for name, project, script, profile, extra in cases:
    command = [sys.executable,str(out/'run_case.py'),name,script,'--project',str(project),'--native','--timeout','240']
    if profile: command += ['--profile',profile]
    if extra: command += ['--args',*extra]
    subprocess.run(command,check=True)
    receipt = json.loads((out/name/'run.json').read_text())
    if receipt['exit_code'] != 0 or receipt['timeout'] or receipt['script_error'] or receipt['source_changes']:
        raise SystemExit('Final matrix failed: '+name)
print('FINAL_LOADING_MATRIX_COMPLETE',flush=True)
