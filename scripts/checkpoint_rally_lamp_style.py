"""RFL04: reversible front-refinement source checkpoint; preserve shared index."""
import hashlib
import json
import re
import subprocess
from run_rally_lamp_style import ROOT, OUT, WORK

MARKER='RALLY-LAMP-STYLE-20261115'
publication=json.loads((OUT/'publication.json').read_text())
digest=lambda data:hashlib.sha256(data).hexdigest()
trackers=['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']
added=['docs/RALLY_LAMP_STYLE_2026_11_15.md','game/tests/fixtures/rally_lamp_style_baseline.json']
for folder in ('scripts','game/tests','game/tests/support'):
    added.extend(p.relative_to(ROOT).as_posix() for p in (ROOT/folder).glob('*rally_lamp_style*')
                 if p.is_file() and p.suffix in ('.py','.ps1','.gd','.uid'))
added.extend(name for name,row in publication['files'].items() if row['before'] is None)
modified=[name for name,row in publication['files'].items() if row['before'] is not None]
names=sorted(set(trackers+added+modified))
after={name:(ROOT/name).read_bytes() for name in names}
before={name:(WORK/'before'/name).read_bytes() for name in modified}
for name,data in before.items(): assert digest(data)==publication['files'][name]['before'],name
for name in trackers:
    pattern=('<!-- '+MARKER+r' -->\r?\n.*?<!-- /'+MARKER+r' -->\r?\n(?:\r?\n)?').encode()
    before[name],count=re.subn(pattern,b'',after[name],flags=re.S)
    assert count==1,name
private=(WORK/'source-checkpoint').resolve()
assert private.is_relative_to(WORK.resolve()) and not private.exists()
private.mkdir(parents=True)
index=digest((ROOT/'.git/index').read_bytes())
def git(*args):
    r=subprocess.run(['git','-c','core.autocrlf=false','-c','core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol',*args],cwd=private,capture_output=True)
    assert r.returncode==0,r.stderr.decode(errors='replace')
    return r.stdout
def write(files):
    for name,data in files.items():
        path=private/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
git('init','--quiet');git('config','user.name','Local source checkpoint');git('config','user.email','checkpoint@invalid.local')
write(before);git('add','--all');git('commit','--quiet','-m','Task-start authored resources and surrounding documentation')
write(after);git('add','--all')
patch=git('diff','--cached','--binary','--full-index','HEAD');(OUT/'source.patch').write_bytes(patch)
git('apply','--check','--reverse',str(OUT/'source.patch'));git('apply','--reverse','--whitespace=error',str(OUT/'source.patch'))
for name in after:
    path=private/name
    assert (not path.exists()) if name not in before else path.read_bytes()==before[name],name
git('apply','--whitespace=error',str(OUT/'source.patch'))
for name,data in after.items():assert (private/name).read_bytes()==data,name
git('diff','--cached','--check');git('commit','--quiet','-m','RLS01-RLS04 preferred classic Rally lamp style')
assert digest((ROOT/'.git/index').read_bytes())==index
receipt=dict(source_files=len(after),forward_byte_exact=True,reverse_byte_exact=True,whitespace_check='passed',
    main_index_unchanged_during_checkpoint=True,private_commit=git('rev-parse','HEAD').decode().strip(),patch_sha256=digest(patch),
    files={name:dict(before_sha256=digest(before[name]) if name in before else None,sha256=digest(data)) for name,data in after.items()},
    scope='Rally lamp builder and two exact recipe migrations, offline tooling, retained assertions and task documentation. Derived scenes/pictures require rebuilding after reversal. Other models and concurrent Garage/index work excluded.')
(OUT/'source-checkpoint.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({k:v for k,v in receipt.items() if k!='files'}))
