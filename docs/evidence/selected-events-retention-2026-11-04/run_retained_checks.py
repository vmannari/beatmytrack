"""Serial offline native regressions, with complete per-process receipts."""
from pathlib import Path
import subprocess
import sys
import time
root=Path(__file__).resolve().parents[3]
runner=Path(__file__).with_name('run_check.py')
if len(sys.argv)>1:
    gate=runner.with_name(sys.argv[1]+'-receipt.json')
    deadline=time.monotonic()+240
    while not gate.exists():
        if time.monotonic()>deadline: raise SystemExit('Earlier native run did not retire')
        time.sleep(0.5)
cases=[
    ('final-events-native','test_selected_events.gd',[]),
    ('final-daily-install','test_daily_event_install.gd',[]),
    ('final-free-selection','test_device_race_preparation.gd',[]),
    ('final-daily-catalog','test_daily_metadata_catalog.gd',[]),
    ('final-reuse','test_race_preparation_reuse.gd',[]),
    ('final-winter-sky','test_winter_sky_reuse.gd',[]),
]
failed=[]
for label,script,args in cases:
    print('CHECK_START',label,flush=True)
    result=subprocess.run([sys.executable,str(runner),label,'res://tests/'+script,'--timeout','220',*args],cwd=root,check=False)
    print('CHECK_END',label,result.returncode,flush=True)
    if result.returncode: failed.append(label)
print('CHECK_FAILURES',failed,flush=True)
sys.exit(bool(failed))
