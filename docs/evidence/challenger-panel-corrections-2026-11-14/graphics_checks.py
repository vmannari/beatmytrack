from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
runner=OUT/'run_check.py'
def run(label,script,method,*args):
    command=[sys.executable,str(runner),label,script,'--audio-driver','Dummy','--rendering-method',method]
    if args:command+=['--',*args]
    subprocess.run(command,cwd=ROOT,check=True)
for full in [False,True]:
    run('prepared-'+('full-' if full else '')+'mobile','res://../docs/evidence/challenger-panel-corrections-2026-11-14/capture.gd','mobile','--stage=prepared','--prepared',*(['--full'] if full else []))
for method in ['gl_compatibility','mobile']:
    run('opaque-'+method,'res://../docs/evidence/challenger-panel-corrections-2026-11-14/opaque.gd',method,'--prepared','--evidence-root=res://../build/challenger-panel-corrections-2026-11-14/opaque')
    run('app-'+method,'res://tests/test_super_rally_ui.gd',method,'--evidence-root=res://../build/challenger-panel-corrections-2026-11-14/app')
