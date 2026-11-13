import hashlib,json,os,shutil,subprocess
from pathlib import Path
from finalise import OWNED
ROOT=Path(__file__).resolve().parents[2];WORK=Path(__file__).resolve().parent;EV=ROOT/'docs/evidence/asset-optimisation-2026-11-08';CP=WORK/'checkpoint-final'
marker='ASSET-OPTIMISATION-20261108'
paths=OWNED+['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','docs/ASSET_OPTIMISATION_2026_11_08.md']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run(args):
    value=subprocess.run(['git',*args],cwd=CP,stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=True)
    return value.stdout
assert not CP.exists(),'Checkpoint already exists; preserve it.'
CP.mkdir()
run(['init','--quiet']);run(['config','user.name','Codex Task Checkpoint']);run(['config','user.email','codex@local.invalid']);run(['config','core.autocrlf','false'])
for relative in paths:
    before=WORK/'before'/relative
    if relative in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
        text=(ROOT/relative).read_text(encoding='utf-8')
        start=text.index('<!-- '+marker+' -->');end=text.index('<!-- /'+marker+' -->')+len('<!-- /'+marker+' -->')
        baseline=(text[:start]+text[end:]).lstrip('\r\n')
        if b'\r\n' in (ROOT/relative).read_bytes():baseline=baseline.replace('\n','\r\n')
        data=baseline.encode()
    elif before.exists():data=before.read_bytes()
    else:continue
    target=CP/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
run(['add','--all']);run(['commit','--quiet','-m','Asset optimisation task base snapshot'])
base=run(['rev-parse','HEAD']).decode().strip()
for relative in paths:
    target=CP/relative;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/relative,target)
run(['add','--all'])
patch=run(['diff','--cached','--binary','--no-ext-diff']);(EV/'task-only.patch').write_bytes(patch)
stat=run(['diff','--cached','--stat']).decode()
run(['commit','--quiet','-m','AOP01-AOP04: pack asset vertices and protect simplified detail'])
head=run(['rev-parse','HEAD']).decode().strip()
expected={p:sha(CP/p) for p in paths}
run(['apply','--reverse','--check',str(EV/'task-only.patch')]);run(['apply','--reverse',str(EV/'task-only.patch')]);run(['apply','--check',str(EV/'task-only.patch')]);run(['apply',str(EV/'task-only.patch')])
assert expected=={p:sha(CP/p) for p in paths}
receipt={'private_repository':str(CP),'base':base,'checkpoint':head,'patch_sha256':sha(EV/'task-only.patch'),'forward_reverse_check':True,'paths':paths,'stat':stat,'main_index_sha256':sha(ROOT/'.git/index')}
initial=json.loads((EV/'initial-index.json').read_text())['sha256'];assert receipt['main_index_sha256']==initial
(EV/'checkpoint.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps({'checkpoint':head,'paths':len(paths),'main_index_unchanged':True}));print(stat)
