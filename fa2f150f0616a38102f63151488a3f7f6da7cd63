from pathlib import Path
import subprocess,sys
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2]
PREFIX='res://../docs/evidence/challenger-surface-joins-2026-11-12/'
cases=[('app-mobile','res://tests/test_super_rally_ui.gd','mobile',['--evidence-root='+PREFIX+'app']),
       ('garage-mobile',PREFIX+'garage_detail.gd','mobile',['--prepared','--stage=final']),
       ('opaque-gl_compatibility',PREFIX+'opaque.gd','gl_compatibility',['--prepared','--evidence-root='+PREFIX+'opaque'])]
for label,script,renderer,args in cases:
    command=[sys.executable,str(OUT/'run_check.py'),label,script,'--audio-driver','Dummy','--rendering-method',renderer,'--',*args]
    subprocess.run(command,cwd=ROOT,check=True)
