"""Final-source focused checks, serial and offline."""
from pathlib import Path
import subprocess
import sys
root=Path(__file__).resolve().parents[3]
runner=Path(__file__).with_name('run_check.py')
cases=[
    ('accepted-events-headless','test_selected_events.gd',['--headless']),
    ('accepted-selective-budget','test_selective_scenery_budget.gd',['--headless']),
    ('accepted-surface-leases','test_retained_winter_surfaces.gd',['--headless']),
    ('accepted-memory','test_race_loading_optimisation.gd',['--headless']),
    ('accepted-events-native','test_selected_events.gd',[]),
    ('accepted-daily-install','test_daily_event_install.gd',[]),
]
failed=[]
for label,script,args in cases:
    print('ACCEPTED_START',label,flush=True)
    result=subprocess.run([sys.executable,str(runner),label,'res://tests/'+script,'--timeout','180',*args],cwd=root,check=False)
    print('ACCEPTED_END',label,result.returncode,flush=True)
    if result.returncode: failed.append(label)
print('ACCEPTED_FAILURES',failed,flush=True)
sys.exit(bool(failed))
