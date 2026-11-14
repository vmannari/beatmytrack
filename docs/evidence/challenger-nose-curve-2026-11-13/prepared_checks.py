from pathlib import Path
import subprocess,sys
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2]
PREFIX='res://../docs/evidence/challenger-nose-curve-2026-11-13/'
cases=[] # Structure and physics have separate, already completed receipts.
for renderer in ['gl_compatibility','mobile']:
    cases.extend([
        ('opaque-'+renderer,PREFIX+'opaque.gd',['--rendering-method',renderer],['--prepared','--evidence-root='+PREFIX+'opaque']),
        ('app-'+renderer,'res://tests/test_super_rally_ui.gd',['--rendering-method',renderer],['--evidence-root='+PREFIX+'app']),
        ('garage-'+renderer,PREFIX+'garage_detail.gd',['--rendering-method',renderer],['--prepared','--stage=final'])])
for label,script,options,args in cases:
    command=[sys.executable,str(OUT/'run_check.py'),label,script,'--audio-driver','Dummy',*options,'--',*args]
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
    print(label,result.returncode,result.stdout[-700:],flush=True)
    assert result.returncode==0,label
