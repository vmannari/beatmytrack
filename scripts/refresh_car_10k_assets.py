"""C10K04: five-car consumer refresh; Challenger is explicitly excluded."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import refresh_car_coarse_models as prior
from run_car_10k import ROOT, OUT, WORK, run
IDS=('compact','kart','forklift','electric','hovercraft')
prior.IDS=IDS

def checked(label, script, *options):
    if run(label,script,*options):raise RuntimeError(label+' failed; see its receipt')

def sources():
    result=prior.sources()
    for folder in ('game/assets/vehicles/car_detail_v1','game/assets/vehicles/compact_plate_v1','game/assets/vehicles/car_10k_v1'):
        for path in (ROOT/folder).glob('*'):
            if path.is_file() and path.suffix in ('.res','.json'):
                relative=path.relative_to(ROOT).as_posix()
                if prior.consumed(relative): result[relative]=hashlib.sha256(path.read_bytes()).hexdigest()
    # Build identities also consume artwork/fonts and non-mesh resource leaves.
    # In particular, a concurrent catalogue-thumbnail refresh can change every
    # conservative car key even when all geometry files remain byte-identical.
    for folder in ('game/assets/vehicles','game/assets/liveries','game/assets/fonts','game/resources'):
        for path in (ROOT/folder).rglob('*'):
            if not path.is_file() or path.suffix in ('.uid','.import'):continue
            relative=path.relative_to(ROOT).as_posix()
            if prior.consumed(relative):result[relative]=hashlib.sha256(path.read_bytes()).hexdigest()
    for name in ('godot-version.txt','scripts/prepared_asset_identity.ps1'):
        result[name]=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
    return result

def identity(label):
    command=['powershell','-NoProfile','-ExecutionPolicy','Bypass','-File',str(ROOT/'scripts/refresh_car_10k_identity.ps1')]
    with (OUT/(label+'.log')).open('w',encoding='utf-8') as log:
        subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    data=json.loads((WORK/'identity/client-build-identity.json').read_text(encoding='utf-8-sig'))
    (OUT/(label+'.json')).write_text(json.dumps(data,indent=2)+'\n')
    return data

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    if '--pictures' in sys.argv:
        checked('garage-pictures','res://../scripts/bake_garage_previews.gd','--rendering-method','gl_compatibility','--','--exclude-vehicle=super_rally')
        subprocess.run([sys.executable,'scripts/check_garage_previews.py','--vehicles='+','.join(IDS)],cwd=ROOT,check=True)
        return
    before=sources()
    if '--finish' not in sys.argv: (OUT/'refresh-inputs.json').write_text(json.dumps(before,indent=2)+'\n')
    if '--finish' not in sys.argv:
        first=identity('identity-before')
        for car in IDS: checked('bases-'+car,'res://tests/bake_modular_car_bases.gd','--headless','--','--vehicle='+car)
        with ThreadPoolExecutor(max_workers=3) as executor:
            jobs=[executor.submit(checked,'kits-'+car,'res://tests/bake_modular_car_kits.gd',*(['--rendering-method','gl_compatibility'] if car=='forklift' else ['--headless']),'--','--vehicle='+car) for car in IDS]
            for job in jobs:job.result()
    else:
        before=json.loads((OUT/'refresh-inputs.json').read_text())
        before={p:h for p,h in before.items() if prior.consumed(p)}
        first=json.loads((OUT/'identity-before.json').read_text())
    for car in IDS: checked('garage-'+car,'res://tests/bake_garage_cars.gd','--headless','--','--vehicle='+car)
    checked('header','res://tests/bake_header_simple_compact.gd','--headless')
    after=sources();changed=sorted(p for p in before.keys()|after.keys() if before.get(p)!=after.get(p))
    (OUT/'refresh-fence.json').write_text(json.dumps({'input_count':len(before),'changed_inputs':changed},indent=2)+'\n')
    if changed:raise RuntimeError('Consumed sources changed during bakes; preserve and refresh affected outputs')
    final=identity('identity-after')
    if any(first['modular_car_sha256'][car]!=final['modular_car_sha256'][car] for car in IDS):raise RuntimeError('Car geometry identities changed during refresh')
    checked('prepared-preflight','res://tests/check_prepared_assets.gd','--headless','--','--exclude-vehicle=super_rally')
    print('DETAIL_REFRESH: bases, all kits, Garage, stock header and complete source/key fences pass',flush=True)

if __name__=='__main__':main()
