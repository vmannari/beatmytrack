"""Rebuild the five-car budget offline; publish only with --publish."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from refresh_car_10k_assets import sources
from run_car_10k import ROOT, OUT, WORK, run

def inputs():
    data={p:h for p,h in sources().items() if not p.startswith('game/assets/vehicles/car_10k_v1/')}
    for name in ['game/tests/bake_car_10k.gd','game/tests/export_car_10k_surfaces.gd',
                 'game/tests/export_car_10k_roles.gd','scripts/dissolve_car_10k.py','scripts/bake_car_10k.py']:
        data[name]=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
    return data

def checked(label,script,*args):
    if run(label,script,*args):raise RuntimeError(label+' failed; publication stopped')

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    before=inputs()
    # Revalidation fences the current inputs and reruns the complete actual-source
    # attribute/key/budget proof. Cached indices can only match exact source keys.
    if '--revalidate' not in sys.argv:
        checked('collect','res://tests/bake_car_10k.gd','--headless','--','--collect')
    if '--resume' not in sys.argv:
        checked('export-dissolve','res://tests/export_car_10k_surfaces.gd','--headless')
        blender=ROOT/'build/tools/blender-4.5.15-windows-x64/blender.exe'
        for suffix,args in [('dissolve',[]),('boundaries',['--','--boundaries'])]:
            command=[str(blender),'--background','--factory-startup','--disable-autoexec',
                     '--python-exit-code','1','--python',str(ROOT/'scripts/dissolve_car_10k.py'),*args]
            with (OUT/('blender-'+suffix+'.log')).open('w',encoding='utf-8') as log:
                subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
        checked('protected-roles','res://tests/export_car_10k_roles.gd','--headless')
    checked('stage-final-five','res://tests/bake_car_10k.gd','--headless','--','--resume','--replan','--dissolved','--boundaries')
    checked('candidate-proof','res://tests/test_car_10k.gd','--headless','--','--candidates')
    after=inputs();changed=sorted(p for p in before.keys()|after.keys() if before.get(p)!=after.get(p))
    (OUT/'producer-fence.json').write_text(json.dumps({'inputs':len(before),'changed':changed},indent=2)+'\n')
    if changed:raise RuntimeError('Consumed inputs changed; preserve private candidates and repeat')
    plan=json.loads((OUT/'plan.json').read_text());directory=ROOT/'game/assets/vehicles/car_10k_v1'
    assert all(9000<=row['after']<=11000 for row in plan['rows'])
    assert not any(key.startswith('super_rally_') for key in plan['parts'])
    qualification={'inputs':after,'plan_sha256':hashlib.sha256((OUT/'plan.json').read_bytes()).hexdigest(),
        'files':{key:hashlib.sha256((WORK/'staged-final-five'/(key+'.res')).read_bytes()).hexdigest() for key in plan['parts']}}
    (OUT/'qualified-candidates.json').write_text(json.dumps(qualification,indent=2)+'\n')
    if '--publish' not in sys.argv:
        print('Five-car candidates qualified; --publish installs the explicit resource set.');return
    publish(plan)

def publish(plan):
    """Install an already qualified explicit plan after native visual review."""
    qualified=json.loads((OUT/'qualified-candidates.json').read_text())
    assert qualified['inputs']==inputs(), 'Consumed inputs changed after qualification'
    assert qualified['plan_sha256']==hashlib.sha256((OUT/'plan.json').read_bytes()).hexdigest()
    assert all(qualified['files'][key]==hashlib.sha256((WORK/'staged-final-five'/(key+'.res')).read_bytes()).hexdigest() for key in plan['parts'])
    directory=ROOT/'game/assets/vehicles/car_10k_v1'
    directory.mkdir(parents=True,exist_ok=True);files={}
    for key in plan['parts']:
        name=key+'.res';data=(WORK/'staged-final-five'/name).read_bytes()
        temporary=directory/(name+'.tmp');temporary.write_bytes(data)
        os.replace(temporary,directory/name);files[name]=hashlib.sha256(data).hexdigest()
    # A newly protected piece must not keep loading an obsolete derivative.
    # Preserve removed, task-owned outputs in disposable build evidence.
    for old in directory.glob('*.res'):
        if old.name in files or not any(old.name.startswith(car+'_') for car in
                ('compact','kart','forklift','electric','hovercraft')):continue
        assert old.resolve().parent==directory.resolve()
        backup=WORK/'superseded-published'/old.name
        backup.parent.mkdir(parents=True,exist_ok=True);backup.write_bytes(old.read_bytes())
        old.unlink()
    (OUT/'publication.json').write_text(json.dumps({'files':files,'source_fence_passed':True,
        'scope':['compact','kart','forklift','electric','hovercraft'],'excluded':'super_rally'},indent=2)+'\n')
    print('Published',len(files),'five-car resources; refresh consumers before use.')

if __name__=='__main__':main()
