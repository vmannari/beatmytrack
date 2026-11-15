"""CLV04: refresh all affected consumers with complete source/key fences."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import refresh_car_coarse_models as prior
from run_car_detail_reduction import ROOT, OUT, WORK, run

def checked(label, script, *options):
    if run(label,script,*options):raise RuntimeError(label+' failed; see its receipt')

def sources():
    result=prior.sources()
    for folder in ('game/assets/vehicles/car_detail_v1','game/assets/vehicles/compact_plate_v1'):
        for path in (ROOT/folder).glob('*'):
            if path.is_file() and path.suffix in ('.res','.json'):
                result[path.relative_to(ROOT).as_posix()]=hashlib.sha256(path.read_bytes()).hexdigest()
    return result

def identity(label):
    command=['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'scripts/refresh_car_detail_identity.ps1')]
    with (OUT/(label+'.log')).open('w',encoding='utf-8') as log:
        subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    data=json.loads((WORK/'identity/client-build-identity.json').read_text(encoding='utf-8-sig'))
    (OUT/(label+'.json')).write_text(json.dumps(data,indent=2)+'\n')
    return data

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    if '--pictures' in sys.argv:
        checked('garage-pictures','res://../scripts/bake_garage_previews.gd','--rendering-method','gl_compatibility')
        subprocess.run([sys.executable,'scripts/check_garage_previews.py'],cwd=ROOT,check=True)
        return
    before=sources();(OUT/'refresh-inputs.json').write_text(json.dumps(before,indent=2)+'\n')
    first=identity('identity-before')
    checked('bases','res://tests/bake_modular_car_bases.gd','--headless')
    with ThreadPoolExecutor(max_workers=3) as executor:
        jobs=[executor.submit(checked,'kits-'+car,'res://tests/bake_modular_car_kits.gd','--headless','--','--vehicle='+car) for car in prior.IDS]
        for job in jobs:job.result()
    checked('garage','res://tests/bake_garage_cars.gd','--headless')
    checked('header','res://tests/bake_header_simple_compact.gd','--headless')
    after=sources();changed=sorted(p for p in before.keys()|after.keys() if before.get(p)!=after.get(p))
    (OUT/'refresh-fence.json').write_text(json.dumps({'input_count':len(before),'changed_inputs':changed},indent=2)+'\n')
    if changed:raise RuntimeError('Consumed sources changed during bakes; preserve and refresh affected outputs')
    final=identity('identity-after')
    if first['modular_car_sha256']!=final['modular_car_sha256']:raise RuntimeError('Car geometry identities changed during refresh')
    checked('prepared-preflight','res://tests/check_prepared_assets.gd','--headless')
    print('DETAIL_REFRESH: bases, all kits, Garage, stock header and complete source/key fences pass',flush=True)

if __name__=='__main__':main()
