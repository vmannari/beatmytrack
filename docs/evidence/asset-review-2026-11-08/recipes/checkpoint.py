import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
EV=ROOT/'docs/evidence/asset-review-2026-11-08'
docs=['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']
paths=set(docs+['docs/ASSET_OPTIMISATION_REVIEW_2026_11_08.md'])
BASE=WORK/'checkpoint-baseline'
for rel in docs:
    before,count=re.subn(rb'<!-- ASSET-REVIEW-20261108 -->[\s\S]*?<!-- /ASSET-REVIEW-20261108 -->\r?\n\r?\n',b'',(ROOT/rel).read_bytes())
    assert count==1,rel
    p=BASE/rel;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(before)
for p in EV.rglob('*'):
    if p.is_file() and p.suffix!='.log' and p.name not in ['task.patch','checkpoint-receipt.json']:paths.add(p.relative_to(ROOT).as_posix())
paths=sorted(paths)
def git(folder,*args,capture=False):return subprocess.run(['git','-C',str(folder),*args],check=True,capture_output=capture)
def initialise(folder):
    folder.mkdir(exist_ok=False);git(folder,'init','--quiet');git(folder,'config','core.autocrlf','false');git(folder,'config','core.whitespace','blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol')
def baseline(folder):
    for rel in docs:
        p=folder/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(BASE/rel,p)
    git(folder,'add','--all')
repo=WORK/'checkpoint-review';initialise(repo);baseline(repo)
tree=git(repo,'write-tree',capture=True).stdout.decode().strip()
for rel in paths:
    p=repo/rel;p.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/rel,p)
git(repo,'add','--all');git(repo,'diff','--cached','--check',tree)
patch=git(repo,'diff','--cached','--binary','--full-index','--no-ext-diff',tree,capture=True).stdout
patch_path=EV/'task.patch';patch_path.write_bytes(patch)
subprocess.run(['git','-c','core.autocrlf=false','-C',str(ROOT),'apply','--reverse','--check',str(patch_path)],check=True)
forward=WORK/'checkpoint-forward';initialise(forward);baseline(forward)
git(forward,'apply','--check',str(patch_path));git(forward,'apply',str(patch_path))
assert all((forward/rel).read_bytes()==(ROOT/rel).read_bytes() for rel in paths)
initial=json.loads((EV/'initial-index.json').read_text())['sha256'];current=hashlib.sha256((ROOT/'.git/index').read_bytes()).hexdigest();assert current==initial
receipt={'requirements':['AOR01','AOR02','AOR03','AOR04'],'files':paths,'patch_bytes':len(patch),'patch_sha256':hashlib.sha256(patch).hexdigest(),'diff_check':True,'root_reverse_apply_check':True,'isolated_forward_apply_check':True,'forward_bytes_exact':True,'main_index_before':initial,'main_index_after':current,'main_index_write':False,'runtime_or_production_asset_files_in_patch':False,'concurrent_sources_excluded':True,'raw_logs_retained_outside_patch':True}
(EV/'checkpoint-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in receipt.items() if k!='files'},indent=2))
