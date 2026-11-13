import hashlib,json,os,shutil,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
EV=ROOT/'docs/evidence/asset-optimisation-2026-11-08'
EV.mkdir(parents=True,exist_ok=True)
manifest={}
for folder in ['game','scripts']:
 for base,dirs,files in os.walk(ROOT/folder):
  dirs[:]=[d for d in dirs if d not in ['.godot','assets','android','__pycache__','build']]
  for name in files:
   p=Path(base)/name
   if p.suffix not in ['.gd','.gdshader','.gdshaderinc','.json','.tres','.py','.ps1','.godot']:continue
   rel=p.relative_to(ROOT);target=WORK/'before'/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
   manifest[rel.as_posix()]=hashlib.sha256(target.read_bytes()).hexdigest()
for rel in ['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
 p=ROOT/rel;target=WORK/'before'/rel;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,target)
(EV/'source-start.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
(EV/'initial-index.json').write_text(json.dumps({'sha256':hashlib.sha256((ROOT/'.git/index').read_bytes()).hexdigest()},indent=2)+'\n',encoding='utf-8')
shutil.copyfile(ROOT/'build/asset-review-2026-11-08/run.py',WORK/'run.py')
print(json.dumps({'source_files':len(manifest)}))
