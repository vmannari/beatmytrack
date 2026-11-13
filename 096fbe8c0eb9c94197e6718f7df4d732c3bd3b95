from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess,sys
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2]
old=OUT.parent/'challenger-panels-2026-11-12'
script=(old/'design_check.gd').read_text().replace('const OUT: String = "res://../docs/evidence/challenger-panels-2026-11-12"','const OUT: String = "res://../docs/evidence/challenger-surface-joins-2026-11-12"')
(OUT/'design.gd').write_text(script)
script=(old/'surface_shading.gd').read_text().replace('FileAccess.open("res://../docs/evidence/challenger-panels-2026-11-12/shading-','FileAccess.open("res://../docs/evidence/challenger-surface-joins-2026-11-12/shading-')
(OUT/'shading.gd').write_text(script)
PREFIX='res://../docs/evidence/challenger-surface-joins-2026-11-12/'
cases=[('joins-final',PREFIX+'joins.gd',[]),('panels-final',PREFIX+'panels.gd',[]),
       ('geometry-final',PREFIX+'design.gd',[]),('shading-final',PREFIX+'shading.gd',[]),
       ('fitted-final','res://tests/test_super_rally_c3_kits.gd',[]),
       ('wash-final','res://tests/test_car_wash.gd',['--evidence-root='+PREFIX+'wash']),
       ('driving-final','res://tests/test_driving.gd',[]),
       ('parser-final','res://../docs/evidence/super-rally-design-2026-11-08/production_parse.gd',[])]
def run(case):
    label,script,args=case
    command=[sys.executable,str(OUT/'run_check.py'),label,script,'--headless','--audio-driver','Dummy']
    if args:command+=['--',*args]
    result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
    print(label,result.returncode,result.stdout[-500:],flush=True)
    return result.returncode
with ThreadPoolExecutor(max_workers=3) as pool:results=list(pool.map(run,cases))
assert all(code==0 for code in results)
