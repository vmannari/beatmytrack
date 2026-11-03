from pathlib import Path
import hashlib,json,shutil,subprocess,tempfile
repo=Path(__file__).resolve().parents[3]
r=Path(__file__).resolve().parent
assets=list(json.loads((r/'asset-start-sha256.json').read_text()))
paths=assets+['game/vehicle/electric_kits.gd', 'game/vehicle/vehicle_customisation.gd', 'game/tests/test_volt_hood_quality.gd', 'game/tests/test_volt_kits.gd', 'game/tests/capture_volt_hood_quality.gd', 'game/tests/test_volt_solid_hoods.gd', 'docs/VOLT_SOLID_HOODS_2026_11_03.md']
stage=r/'checkpoint-git'
stage.mkdir(exist_ok=True)
subprocess.run(['git','init','--quiet',str(stage)],check=True)
(stage/'.git/info/attributes').write_text('* -text\n')
left=stage/'before';right=stage/'after'
for base in [left,right]:base.mkdir(exist_ok=True)
for name in paths:
 before=r/'before'/name;after=repo/name
 if before.exists():
  p=left/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(before,p)
 p=right/name;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(after,p)
args=['git','-c','core.autocrlf=false','diff','--no-index','--no-ext-diff','--binary','--no-renames','--','before','after']
out=subprocess.run(args,cwd=stage,capture_output=True)
if out.returncode!=1:raise RuntimeError(out.stderr.decode(errors='replace'))
patch=out.stdout.replace(b'a/before/',b'a/').replace(b'b/after/',b'b/').replace(b'a/after/',b'a/').replace(b'b/before/',b'b/')
patch_path=r/'task-only.patch';patch_path.write_bytes(patch)
check=Path(tempfile.mkdtemp(prefix='volt-solid-hoods-roundtrip-raw-',dir=repo/'tmp'))
subprocess.run(['git','init','--quiet',str(check)],check=True)
(check/'.git/info/attributes').write_text('* -text\n')
shutil.copytree(left,check,dirs_exist_ok=True)
def apply(*extra):
 a=['git','-c','core.autocrlf=false','apply',*extra,str(patch_path)]
 p=subprocess.run(a,cwd=check,capture_output=True)
 if p.returncode:raise RuntimeError(p.stderr.decode(errors='replace'))
def same(expected):
 for name in paths:
  a=expected/name;b=check/name
  if a.exists()!=b.exists() or (a.exists() and a.read_bytes()!=b.read_bytes()):raise RuntimeError('Mismatch: '+name)
apply('--check');apply();same(right)
apply('--reverse','--check');apply('--reverse');same(left)
report={'files':len(paths),'patch_bytes':len(patch),'forward_content_exact':True,'reverse_content_exact':True,'main_index_written':False,'after_sha256':{name:hashlib.sha256((repo/name).read_bytes()).hexdigest() for name in paths}}
(r/'checkpoint-report.json').write_text(json.dumps(report,indent=2))
print(json.dumps({k:v for k,v in report.items() if k!='after_sha256'}))
