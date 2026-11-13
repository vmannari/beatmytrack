"""Retain the measured experiment and remove only its App scheduling changes."""
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

E = Path(__file__).resolve().parent
ROOT = E.parents[2]
OUT = ROOT/'build/tablet-loading-fixes-20261107'
rejected = E/'rejected-startup-deferral'
rejected.mkdir(exist_ok=False)
archive = OUT/'rejected-startup-deferral'
archive.mkdir(exist_ok=False)
patch = E/'runtime.patch'
shutil.copyfile(patch,rejected/'runtime-with-deferral.patch')
for project in ['qualified','profiled-qualified']:
    folder = archive/project
    folder.mkdir()
    shutil.copyfile(OUT/project/'game/core/app.gd',folder/'app.gd')
    receipt = json.loads((OUT/(project+'-export.json')).read_text())
    saved_apk = folder/'circuit01-arm64.apk'
    shutil.copyfile(receipt['apk']['path'],saved_apk)
    assert hashlib.sha256(saved_apk.read_bytes()).hexdigest()==receipt['apk']['sha256']
    receipt['archived_apk_path'] = str(saved_apk)
    (rejected/(project+'-export.json')).write_text(json.dumps(receipt,indent=2)+'\n')
    shutil.copytree(OUT/'exports'/project,folder/'export',ignore=shutil.ignore_patterns('profile'))
command = ['git','apply','--reverse','--include=game/core/app.gd',str(patch)]
subprocess.run(command[:2]+['--check']+command[2:],cwd=ROOT,check=True)
subprocess.run(command,cwd=ROOT,check=True)
shutil.copyfile(OUT.parent/'race-verification-speed-20261107/frozen/game/core/app.gd',OUT/'qualified/game/core/app.gd')
shutil.copyfile(OUT.parent/'tablet-phase-profile-20261107/isolated-current/game/core/app.gd',OUT/'profiled-qualified/game/core/app.gd')
source = ROOT/'game/tests/test_initial_menu_readiness.gd'
shutil.copyfile(source,rejected/'test_initial_menu_readiness.gd')
source.unlink() # task-created experiment only; retained above
uid = source.with_suffix('.gd.uid')
if uid.exists():
    shutil.copyfile(uid,rejected/uid.name)
    uid.unlink()
data = patch.read_text()
chunks = ['--- a/'+chunk for chunk in data.split('--- a/')[1:]]
patch.write_text(''.join(c for c in chunks if not c.startswith('--- a/game/core/app.gd\n')),newline='\n')
(rejected/'decision.json').write_text(json.dumps({'reason':'No resolved startup gain in fresh control; first Garage median 1585 to 1940 ms; preserve original scheduling for final qualification.',
    'removed_runtime_change':'game/core/app.gd','main_concurrent_edits_preserved':True,
    'remaining_runtime':['game/backend/menu_snapshot_writer.gd','game/vehicle/prepared_car_cache.gd','game/track/spatial_mesh_chunks.gd','game/track/spatial_mesh_preparation.gd']},indent=2)+'\n')
print('STARTUP_DEFERRAL_ARCHIVED_AND_REMOVED')
