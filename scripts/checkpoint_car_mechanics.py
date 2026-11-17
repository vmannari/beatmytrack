"""CME05: reversible task-only source checkpoint using a private Git index."""
import hashlib
import json
import re
import subprocess
import sys
from run_car_mechanics import ROOT, OUT, WORK

MARKER='CAR-MECHANICS-20261117'
pub=json.loads((OUT/'publication.json').read_text())['files']
trackers=['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']
new=['docs/CAR_MECHANICS_2026_11_17.md']
for folder in ['scripts','game/tests']:
    new.extend(p.relative_to(ROOT).as_posix() for p in (ROOT/folder).glob('*car_mechanics*')
               if p.is_file() and p.suffix in ['.py','.ps1','.gd','.uid'])
new.extend(name for name,row in pub.items() if row['before'] is None)
modified=[name for name,row in pub.items() if row['before'] is not None]
modified.append('game/tests/support/car_refinement_lods.gd')
names=sorted(set(new+modified+trackers))
after={name:(ROOT/name).read_bytes() for name in names}
before={name:(WORK/'before'/name).read_bytes() for name in modified}
digest=lambda data:hashlib.sha256(data).hexdigest()
for name,row in pub.items():assert digest(after[name])==row['after']
for name in trackers:
    pattern=('<!-- '+MARKER+r' -->\r?\n.*?<!-- /'+MARKER+r' -->\r?\n(?:\r?\n)?').encode()
    before[name],count=re.subn(pattern,b'',after[name],flags=re.S);assert count==1
private=(WORK/('source-checkpoint-final' if '--final' in sys.argv else 'source-checkpoint')).resolve()
assert private.is_relative_to(WORK.resolve()) and not private.exists()
private.mkdir(parents=True)
index=digest((ROOT/'.git/index').read_bytes())
def git(*args):
    result=subprocess.run(['git','-c','core.autocrlf=false','-c',
        'core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol',*args],
        cwd=private,capture_output=True)
    assert result.returncode==0,result.stderr.decode(errors='replace')
    return result.stdout
def write(files):
    for name,data in files.items():
        target=private/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
git('init','--quiet');git('config','user.name','Local source checkpoint');git('config','user.email','checkpoint@invalid.local')
write(before);git('add','--all');git('commit','--quiet','-m','Exact preceding mechanical-detail sources')
write(after);git('add','--all')
patch=git('diff','--cached','--binary','--full-index','HEAD');patch_path=OUT/'source.patch';patch_path.write_bytes(patch)
git('apply','--check','--reverse',str(patch_path));git('apply','--reverse','--whitespace=error',str(patch_path))
for name in after:
    target=private/name
    assert (not target.exists()) if name not in before else target.read_bytes()==before[name],name
git('apply','--whitespace=error',str(patch_path))
for name,data in after.items():assert (private/name).read_bytes()==data,name
git('diff','--cached','--check');git('commit','--quiet','-m','CME01-CME05 appearance-preserving mechanical savings')
bundle=WORK/(private.name+'.bundle');git('bundle','create',str(bundle),'--all');git('bundle','verify',str(bundle))
assert digest((ROOT/'.git/index').read_bytes())==index
receipt=dict(source_files=len(names),forward_byte_exact=True,reverse_byte_exact=True,
             shared_index_unchanged_during_checkpoint=True,whitespace_check=True,
             commit=git('rev-parse','HEAD').decode().strip(),patch_sha256=digest(patch),
             files={name:dict(before_sha256=digest(before[name]) if name in before else None,
                              after_sha256=digest(data)) for name,data in after.items()})
(OUT/'source-checkpoint.json').write_text(json.dumps(receipt,indent=2)+'\n')
print('MECHANICS_CHECKPOINT',len(names),'sources; exact forward/reverse; shared index preserved')
