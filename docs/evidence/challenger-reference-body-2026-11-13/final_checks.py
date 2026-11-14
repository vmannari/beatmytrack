from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import subprocess,sys
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2]
OLD=OUT.parent/'challenger-surface-joins-2026-11-12'
for name in ['design.gd','shading.gd','panels.gd']:
    s=(OLD/name).read_text().replace('FileAccess.open("res://../docs/evidence/challenger-surface-joins-2026-11-12/','FileAccess.open("res://../docs/evidence/challenger-reference-body-2026-11-13/')
    s=s.replace('const OUT: String = "res://../docs/evidence/challenger-surface-joins-2026-11-12"','const OUT: String = "res://../docs/evidence/challenger-reference-body-2026-11-13"')
    (OUT/name).write_text(s)
P='res://../docs/evidence/challenger-reference-body-2026-11-13/'
cases=[('reference-final',P+'reference_geometry.gd',[]),('hood-final',P+'hood_contract.gd',[]),('geometry-final',P+'design.gd',[]),('shading-final',P+'shading.gd',[]),
       ('fitted-final','res://tests/test_super_rally_c3_kits.gd',[]),('wash-final','res://tests/test_car_wash.gd',['--evidence-root='+P+'wash']),
       ('driving-final','res://tests/test_driving.gd',[]),('parser-final','res://../docs/evidence/super-rally-design-2026-11-08/production_parse.gd',[])]
def run(case):
    label,script,args=case
    command=[sys.executable,str(OUT/'run_check.py'),label,script,'--headless','--audio-driver','Dummy']
    if args:command+=['--',*args]
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
    print(label,result.returncode,result.stdout[-750:],flush=True)
    return result.returncode
with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(run,cases))
assert all(code==0 for code in results)
