from pathlib import Path
import json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
run=OUT/'run_check.py';base='res://../docs/evidence/challenger-hood-redesign-2026-11-16/'
tests=[
 ('opacity-gl',base+'opaque.gd','gl_compatibility',['--prepared','--evidence-root=res://../build/challenger-hood-redesign-2026-11-16/opacity']),
 ('prepared-views-gl',base+'capture.gd','gl_compatibility',['--prepared','--stage=final','--owner-only']),
 ('opacity-mobile',base+'opaque.gd','mobile',['--prepared','--evidence-root=res://../build/challenger-hood-redesign-2026-11-16/opacity']),
 ('prepared-views-mobile',base+'capture.gd','mobile',['--prepared','--stage=final','--owner-only']),
 ('prepared-close-gl',base+'capture.gd','gl_compatibility',['--prepared','--full','--owner-only','--white-only','--stage=final-close']),
 ('prepared-close-mobile',base+'capture.gd','mobile',['--prepared','--full','--owner-only','--white-only','--stage=final-close']),
 ('app-gl','res://tests/test_super_rally_ui.gd','gl_compatibility',['--evidence-root=res://../build/challenger-hood-redesign-2026-11-16/app']),
 ('app-mobile','res://tests/test_super_rally_ui.gd','mobile',['--evidence-root=res://../build/challenger-hood-redesign-2026-11-16/app'])]
start=sys.argv[1] if len(sys.argv)>1 else ''
results=json.loads((OUT/'gpu-checks.json').read_text()) if start else []
results=[row for row in results if row['exit_code']==0]
active=not start
for label,script,renderer,arguments in tests:
    if label==start:active=True
    if not active:continue
    command=[sys.executable,str(run),label,script,'--rendering-method',renderer,'--audio-driver','Dummy','--',*arguments]
    started=time.monotonic();result=subprocess.run(command,cwd=ROOT)
    results.append({'label':label,'exit_code':result.returncode,'elapsed_seconds':time.monotonic()-started})
    (OUT/'gpu-checks.json').write_text(json.dumps(results,indent=2))
    if result.returncode:sys.exit(result.returncode)
print('SIDE_GPU_CHECKS all final desktop checks complete',flush=True)
