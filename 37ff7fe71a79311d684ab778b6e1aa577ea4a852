from pathlib import Path
import subprocess,sys
root=Path.cwd();lab=root/'build/cold-render-investigation-2026-10-27'
cases=[
    ['cache-reuse','original','standalone','gl_compatibility','--reuse-profile=original-standalone'],
    ['representatives-split','representatives_split','standalone','gl_compatibility'],
    ['mobile-original','original','standalone','mobile'],
    ['separate-thread','thread_separate','standalone','gl_compatibility'],
    ['rename-callback','rename_callback','standalone','gl_compatibility'],
    ['app-original','original','app','gl_compatibility'],
]
for case in cases:
    with (lab/(case[0]+'-runner.log')).open('wb') as log:
        result=subprocess.run([sys.executable,str(lab/'run_probe.py'),*case],cwd=root,stdout=log,stderr=subprocess.STDOUT)
    print(case[0],result.returncode,flush=True)
