import json
from pathlib import Path
import subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'docs/evidence/sec09-sec10-fixes-2026-10-24'
def unix(p):return '/mnt/'+p.drive[0].lower()+p.as_posix()[2:]
receipt=json.loads((ROOT/'build/security-deploy-2026-10-24/receipt.private.json').read_text(encoding='utf-8'))
args=['wsl.exe','-d','Ubuntu','--','docker','run','--rm','--network=none','--label','bmt.sec0910=20261024',
      '-e','PYTHONPATH=/review/backend:/review/backend/tests','--workdir','/review/backend',
      '--mount','type=bind,src='+unix(ROOT/'backend')+',dst=/review/backend,readonly',
      '--mount','type=bind,src='+unix(OUT)+',dst=/results','--entrypoint','python',receipt['local_tag'],
      '-m','pytest','tests/test_http_server.py','-q','--tb=short','--basetemp=/tmp/sec0910-http',
      '-p','no:cacheprovider','--junitxml=/results/linux-http.xml']
value=subprocess.run(args,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=180)
(OUT/'linux-http.log').write_text(value.stdout+value.stderr,encoding='utf-8')
print((value.stdout+value.stderr)[-2500:])
raise SystemExit(value.returncode)
