"""Byte-exact source checkpoint in a disposable private Git repository."""
from pathlib import Path
import hashlib, json, subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
SCRATCH=ROOT/'build/challenger-continuous-side-2026-11-15/source-checkpoint-original-shape-final'
SCRATCH.mkdir(parents=True,exist_ok=True)
files=['scripts/prepare_challenger.py','scripts/challenger_exterior_geometry.py','scripts/challenger_side_surface.py']
sha=lambda data:hashlib.sha256(data).hexdigest()
index_before=sha((ROOT/'.git/index').read_bytes())
before={n:(OUT/'before'/n).read_bytes() if (OUT/'before'/n).is_file() else None for n in files}
after={n:(ROOT/n).read_bytes() for n in files}
def git(*args):
    return subprocess.run(['git','-C',str(SCRATCH),*args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE).stdout
git('init','-q')
git('config','core.autocrlf','false')
(SCRATCH/'.gitattributes').write_bytes(b'* -text\n')
for n,data in before.items():
    if data is None:continue
    p=SCRATCH/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
git('add','.')
git('-c','user.name=Codex','-c','user.email=codex@local.invalid','commit','-q','--no-gpg-sign','-m','Private task-start source checkpoint')
for n,data in after.items():
    p=SCRATCH/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
git('add','-A')
patch=OUT/'source-only.patch'
patch.write_bytes(git('diff','--cached','--binary','--no-ext-diff'))
git('apply','--reverse','--check',str(patch))
git('apply','--reverse',str(patch))
assert all((not (SCRATCH/n).exists()) if data is None else (SCRATCH/n).read_bytes()==data for n,data in before.items())
git('apply','--check',str(patch))
git('apply',str(patch))
assert all((SCRATCH/n).read_bytes()==data for n,data in after.items())
assert all((ROOT/n).read_bytes()==data for n,data in after.items())
receipt={'forward_and_reverse_byte_exact':True,'main_index_unchanged':index_before==sha((ROOT/'.git/index').read_bytes()),
         'before':{n:None if data is None else sha(data) for n,data in before.items()},'after':{n:sha(data) for n,data in after.items()},'patch_sha256':sha(patch.read_bytes())}
(OUT/'source-checkpoint.json').write_text(json.dumps(receipt,indent=2))
assert receipt['main_index_unchanged']
print('SOURCE_CHECKPOINT: 3 sources; forward/reverse byte exact; main index unchanged')

