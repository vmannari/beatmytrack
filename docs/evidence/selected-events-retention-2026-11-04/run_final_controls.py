"""Run final native controls and renderer checks serially, offline."""
from pathlib import Path
import subprocess
import sys
root=Path(__file__).resolve().parents[3]
runner=Path(__file__).with_name('run_check.py')
cases=[
    ('before-free-selection','test_before_selected_free_race.gd',[]),
    ('active-winter-sky','test_active_winter_sky_policy.gd',[]),
    ('final-wind-compat','test_winter_ground_snow.gd',['--output-dir=res://../docs/evidence/selected-events-retention-2026-11-04/final-wind-compat']),
    ('final-scenery-mobile','test_selected_scenery_retention.gd',['--renderer','mobile','--viewport=960x540']),
]
failed=[]
for label,script,args in cases:
    print('CONTROL_START',label,flush=True)
    result=subprocess.run([sys.executable,str(runner),label,'res://tests/'+script,'--timeout','280',*args],cwd=root,check=False)
    print('CONTROL_END',label,result.returncode,flush=True)
    if result.returncode: failed.append(label)
print('CONTROL_FAILURES',failed,flush=True)
sys.exit(bool(failed))
