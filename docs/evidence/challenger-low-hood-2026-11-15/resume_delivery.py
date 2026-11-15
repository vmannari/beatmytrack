"""Finish the interrupted delivery after the unchanged Mobile control passes."""
from pathlib import Path
import json,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
labels=['opacity-gl','prepared-views-gl','opacity-mobile','prepared-views-mobile','prepared-close-gl','prepared-close-mobile','app-gl','app-mobile']
for label in labels:
    receipt=json.loads((OUT/(label+'-command.json')).read_text())
    assert receipt['exit_code']==0 and receipt['script_errors']==0,label
rows=json.loads((OUT/'gpu-checks.json').read_text())
assert len(rows)==8 and {r['label'] for r in rows}==set(labels) and all(r['exit_code']==0 for r in rows)
command=[sys.executable,'scripts/check_garage_selection_pictures.py'];started=time.monotonic()
with (OUT/'selection-picture-final.log').open('w') as log:
    result=subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=120)
(OUT/'delivery-continuation.json').write_text(json.dumps({'resumed_after':'initial Mobile opacity repeat/probe failure; unchanged repeat passed','all_eight_gpu_receipts_passed':True,'command':command,'exit_code':result.returncode,'seconds':time.monotonic()-started},indent=2))
assert result.returncode==0
print((OUT/'selection-picture-final.log').read_text())
print('LOW_HOOD_DELIVERY_COMPLETE')
