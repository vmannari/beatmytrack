"""Task-owned stable source and prepared assets; never edit shared resources."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'build/tablet-loading-fixes-20261107'
EVIDENCE = Path(__file__).resolve().parent
FROZEN = OUT / 'candidate'
assert not FROZEN.exists(), 'Do not replace an existing test snapshot'
FROZEN.mkdir(parents=True)
copied = {}
shared = []

def copy(src, dst):
    if src.is_dir():
        dst.mkdir(parents=True, exist_ok=True)
        for item in src.iterdir():
            copy(item, dst/item.name)
    else:
        dst.parent.mkdir(parents=True, exist_ok=True)
        data = src.read_bytes()
        dst.write_bytes(data)
        copied[dst.relative_to(FROZEN).as_posix()] = hashlib.sha256(data).hexdigest()

def junction(src, dst):
    assert src.resolve().is_relative_to(ROOT.resolve())
    assert dst.absolute().is_relative_to(FROZEN.absolute())
    dst.parent.mkdir(parents=True, exist_ok=True)
    quote = lambda p: "'" + str(p).replace("'", "''") + "'"
    subprocess.run(['powershell','-NoProfile','-Command',
        'New-Item -ItemType Junction -Path '+quote(dst)+' -Target '+quote(src)+' | Out-Null'], check=True)
    shared.append({'source':str(src),'destination':str(dst)})

for path in (ROOT/'game').iterdir():
    if path.name not in ('.godot','android','assets'):
        copy(path, FROZEN/'game'/path.name)
for path in (ROOT/'game/assets').iterdir():
    if path.name in ('garage','menu','vehicles') or path.is_file():
        copy(path, FROZEN/'game/assets'/path.name)
    else:
        junction(path, FROZEN/'game/assets'/path.name)
for name in ('global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg'):
    path = ROOT/'game/.godot'/name
    if path.exists(): copy(path, FROZEN/'game/.godot'/name)
junction(ROOT/'game/.godot/imported', FROZEN/'game/.godot/imported')
for name in ('scripts','godot-version.txt','.gitattributes'):
    copy(ROOT/name,FROZEN/name)
copy(ROOT/'backend/tests/fixtures',FROZEN/'backend/tests/fixtures')
for name in ('native','docs'):
    junction(ROOT/name,FROZEN/name)
before = EVIDENCE/'before'
for relative in copied:
    if relative.startswith('game/') and relative.endswith(('.gd','.gdshader','.gdshaderinc')) and '/tests/' not in relative:
        target = before/relative
        target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(FROZEN/relative,target)
result = {'candidate':str(FROZEN),'files':copied,'shared':shared,
          'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()}
(EVIDENCE/'baseline.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'candidate':str(FROZEN),'copied':len(copied),'shared':len(shared)}))
