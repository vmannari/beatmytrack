"""Verify current prepared assets after final picture imports and publication."""
from pathlib import Path
import json,subprocess,sys,time

ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
PREFIX='res://../docs/evidence/challenger-surface-simplification-2026-11-14/'
for renderer in ['gl_compatibility','mobile']:
    subprocess.run([sys.executable,str(OUT/'run_check.py'),'app-handoff-'+renderer,'res://tests/test_super_rally_ui.gd',
                    '--audio-driver','Dummy','--rendering-method',renderer,'--','--evidence-root='+PREFIX+'app-handoff'],cwd=ROOT,check=True)
subprocess.run([sys.executable,str(OUT/'run_check.py'),'prepared-final','res://tests/check_prepared_assets.gd','--headless','--audio-driver','Dummy'],cwd=ROOT,check=True)
command=[sys.executable,'scripts/check_garage_previews.py']
started=time.monotonic();result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,check=True)
(OUT/'catalogue-final.log').write_text(result.stdout+result.stderr)
(OUT/'catalogue-final-command.json').write_text(json.dumps({'command':command,'exit_code':result.returncode,'seconds':time.monotonic()-started},indent=2))
print(result.stdout)
