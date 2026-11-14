from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess
import sys
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2]
P='res://../docs/evidence/challenger-corner-roll-2026-11-13/'
cases=[
    ('shoulder-final',P+'shoulder_geometry.gd',[]),
    ('hood-final',P+'hood_contract.gd',[]),
    ('fitted-final','res://tests/test_super_rally_c3_kits.gd',[]),
    ('modules','res://tests/test_modular_car_assets.gd',['--vehicle=super_rally','--all-kits']),
    ('physics','res://tests/test_super_rally.gd',['--prepared','--evidence-root='+P+'physics']),
    ('wash-final','res://tests/test_car_wash.gd',['--evidence-root='+P+'wash']),
    ('parser-final','res://../docs/evidence/super-rally-design-2026-11-08/production_parse.gd',[]),
]
def run(case):
    label,script,args=case
    command=[sys.executable,str(OUT/'run_check.py'),label,script,'--headless','--audio-driver','Dummy']
    if args:command+=['--',*args]
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
    print(label,result.returncode,result.stdout[-950:],flush=True)
    return result.returncode
with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(run,cases))
sys.exit(1 if any(results) else 0)
