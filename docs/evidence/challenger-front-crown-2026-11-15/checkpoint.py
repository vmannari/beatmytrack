"""Task-only source patch, checked forwards and backwards outside the shared index."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[3];OUT=Path(__file__).resolve().parent
BUILD=ROOT/'build'/OUT.name;SCRATCH=BUILD/'source-checkpoint'
SCRATCH.mkdir(exist_ok=True)
files=['scripts/challenger_side_finish.py','scripts/challenger_nose_finish.py','scripts/challenger_detail_geometry.py','scripts/prepare_challenger.py','game/vehicle/super_rally_model.gd']
sha=lambda data:hashlib.sha256(data).hexdigest()
index=sha((ROOT/'.git/index').read_bytes())
before={name:(BUILD/'before'/name).read_bytes() if (BUILD/'before'/name).exists() else None for name in files}
after={name:(ROOT/name).read_bytes() for name in files}
def git(*args):
    return subprocess.run(['git','-C',str(SCRATCH),*args],check=True,stdout=subprocess.PIPE,stderr=subprocess.PIPE).stdout
git('init','-q');git('config','core.autocrlf','false')
(SCRATCH/'.gitattributes').write_bytes(b'* -text\n')
for name,data in before.items():
    if data is None:continue
    p=SCRATCH/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
git('add','-f','.')
git('-c','user.name=Codex','-c','user.email=codex@local.invalid','commit','-q','--no-gpg-sign','-m','Private task-start surface source')
for name,data in after.items():
    p=SCRATCH/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
git('add','-f','.')
patch=OUT/'source-only.patch';patch.write_bytes(git('diff','--cached','--binary','--no-ext-diff'))
git('apply','--reverse','--check',str(patch));git('apply','--reverse',str(patch))
assert all((not (SCRATCH/name).exists()) if data is None else (SCRATCH/name).read_bytes()==data for name,data in before.items())
git('apply','--check',str(patch));git('apply',str(patch))
assert all((SCRATCH/name).read_bytes()==data for name,data in after.items())
receipt={'forward_reverse_byte_exact':True,'shared_index_unchanged_during_checkpoint':index==sha((ROOT/'.git/index').read_bytes()),'before':{n:None if d is None else sha(d) for n,d in before.items()},'after':{n:sha(d) for n,d in after.items()},'patch_sha256':sha(patch.read_bytes())}
assert receipt['shared_index_unchanged_during_checkpoint']
(OUT/'source-checkpoint.json').write_text(json.dumps(receipt,indent=2))
print('SOURCE_CHECKPOINT five source files; forward and reverse exact; shared index untouched.')
