"""Native transport against an isolated local API, including explicit retry."""
import os,subprocess,sys
from pathlib import Path
work=Path(__file__).resolve().parent;root=work.parents[1]
out=root/'docs/evidence/race-verification-speed-2026-11-07'
profile=work/'http-profile'
for part in ('appdata','localappdata'):(profile/part).mkdir(parents=True,exist_ok=True)
env=dict(os.environ,APPDATA=str(profile/'appdata'),LOCALAPPDATA=str(profile/'localappdata'),BMT_API_URL='',PYTHONPATH=str(root/'backend'))
command=[sys.executable,'-m','pytest','backend/tests/test_outcome_http.py','backend/tests/test_non_improving_http.py','-q','-s',
         '--basetemp='+str(work/'http-tests'),'--junitxml='+str(out/'http-regression.xml')]
with (out/'http-regression.log').open('w',encoding='utf-8') as log:
    result=subprocess.run(command,cwd=root,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=420,creationflags=subprocess.CREATE_NO_WINDOW)
print((out/'http-regression.log').read_text()[-5000:],flush=True)
raise SystemExit(result.returncode)
