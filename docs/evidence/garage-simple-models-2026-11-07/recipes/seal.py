import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
DEST=WORK/'frozen'
native=subprocess.run(['git','-C',str(ROOT),'ls-files','--cached','--others','--exclude-standard','--','native'],capture_output=True,text=True,check=True).stdout.splitlines()
for rel in native:
    source=ROOT/rel
    if source.is_file():
        target=DEST/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,target)
types={'.gd','.gdshader','.gdshaderinc','.tres','.json','.ps1','.py','.godot','.cfg','.po','.pot','.cpp','.h','.txt','.gdextension'}
paths=[]
for folder in ['game','scripts','native']:
    for base,folders,files in os.walk(ROOT/folder):
        folders[:]=[x for x in folders if x not in ['.godot','__pycache__','android','build','.git']]
        for name in files:
            source=Path(base)/name
            if source.suffix in types and (DEST/source.relative_to(ROOT)).is_file():paths.append(source.relative_to(ROOT).as_posix())
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
for attempt in range(4):
    for rel in paths:
        source=ROOT/rel;target=DEST/rel
        assert target.resolve().is_relative_to(DEST.resolve())
        temporary=target.with_name(target.name+'.snapshot-tmp')
        shutil.copyfile(source,temporary);os.replace(temporary,target)
    hashes={rel:digest(DEST/rel) for rel in paths}
    changed=[rel for rel,value in hashes.items() if digest(ROOT/rel)!=value]
    if not changed:break
assert not changed,changed
shutil.copyfile(ROOT/'.gitignore',DEST/'.gitignore')
subprocess.run(['git','-C',str(DEST),'init','--quiet'],check=True)
subprocess.run(['git','-C',str(DEST),'config','core.autocrlf','false'],check=True)
receipt={'root':str(DEST),'source_sha256':hashes,'sealing_attempts':attempt+1,
         'changed_at_seal':changed,'generated_outputs_are_independent_copies':True,
         'source_files_are_independent_copies':True,'shader_cache_shared':False,
         'reason':'Live concurrent physics/project edits; frozen validation does not mutate those sources.'}
(WORK/'freeze-receipt.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
print(json.dumps({'source_files':len(hashes),'sealing_attempts':attempt+1,'changed_at_seal':changed}))
