"""Freeze mutable code/prepared assets; share unchanged imported/static content.

All copies/junctions are task-owned. No deletion or mutation of shared assets.
Both control and candidate resolve res:// against this same frozen project.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[2]
owned = root/'build/race-loading-alternatives-20261106'/('frozen-'+str(time.time_ns()))
game = owned/'game'
game.mkdir(parents=True)
fixture = owned/'backend/tests/fixtures/verified_oval.json'
fixture.parent.mkdir(parents=True,exist_ok=True)
shutil.copyfile(root/'backend/tests/fixtures/verified_oval.json',fixture)
copied = [fixture]
shared = []

def copy_tree(source,destination):
    if source.is_file():
        destination.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source,destination)
        copied.append(destination)
    else:
        destination.mkdir(parents=True,exist_ok=True)
        for path in source.iterdir(): copy_tree(path,destination/path.name)

def junction(source,destination):
    assert source.resolve().is_relative_to(root.resolve())
    assert destination.absolute().is_relative_to(owned.absolute())
    # These are fixed local paths, safely quoted as PowerShell literals.
    command = 'New-Item -ItemType Junction -Path '+"'"+str(destination).replace("'","''")+"' -Target '"+str(source).replace("'","''")+"' | Out-Null"
    subprocess.run(['powershell','-NoProfile','-Command',command],check=True)
    shared.append(dict(source=str(source),path=str(destination)))

for path in (root/'game').iterdir():
    if path.name in ('.godot','assets','android'): continue
    copy_tree(path,game/path.name)
(game/'assets').mkdir()
for path in (root/'game/assets').iterdir():
    if path.name in ('garage','menu'): copy_tree(path,game/'assets'/path.name)
    elif path.name == 'vehicles':
        (game/'assets/vehicles').mkdir()
        for bank in path.iterdir():
            destination = game/'assets/vehicles'/bank.name
            if bank.name in ('modular_car_bases_v1','modular_kits_v1') or bank.is_file(): copy_tree(bank,destination)
            else: junction(bank,destination)
    elif path.is_dir(): junction(path,game/'assets'/path.name)
    else: copy_tree(path,game/'assets'/path.name)
(game/'.godot').mkdir()
for name in ('global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg'):
    source = root/'game/.godot'/name
    if source.exists(): copy_tree(source,game/'.godot'/name)
junction(root/'game/.godot/imported',game/'.godot/imported')
for name in ('docs','native'):
    if (root/name).is_dir(): junction(root/name,owned/name)
manifest = {path.relative_to(owned).as_posix():hashlib.sha256(path.read_bytes()).hexdigest() for path in copied}
report = dict(project=str(game),copied_files=len(copied),copied_sha256=manifest,shared=shared)
(evidence/'frozen-project.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'project':str(game),'copied_files':len(copied),'shared_directories':len(shared)}))


