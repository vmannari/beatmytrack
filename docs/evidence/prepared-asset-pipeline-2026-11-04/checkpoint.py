"""Task-only binary/source checkpoint, checked with two owned private Git repos."""
import hashlib
import json
from pathlib import Path
import subprocess
import time

EVIDENCE=Path(__file__).resolve().parent
ROOT=EVIDENCE.parents[2]
baseline=EVIDENCE/'before'
excluded={'AGENTS.md','DEVELOPMENT_STATUS.md','game/core/build_identity.gd','game/project.godot'}
added=[
 'game/vehicle/prepared_asset_dependencies.json','game/vehicle/prepared_asset_sources.gd',
 'scripts/prepared_asset_identity.ps1','scripts/prepare_car_assets.py','scripts/check_prepared_asset_dependencies.py',
 'scripts/test_prepared_dependency_receipts.py','scripts/test_garage_preview_provenance.py',
 'game/tests/check_prepared_assets.gd','game/tests/test_prepared_dependency_receipts.gd',
 'game/tests/test_prepared_pipeline_visuals.gd','game/tests/test_prepared_garage_render.gd',
 'docs/PREPARED_ASSET_PIPELINE_2026_11_04.md',
 *['docs/evidence/prepared-asset-pipeline-2026-11-04/'+name for name in ('run_check.py','summarize.py','checkpoint.py')]]
before={};after={}
for path in baseline.rglob('*'):
 if not path.is_file():continue
 name=path.relative_to(baseline).as_posix()
 if name in excluded:continue
 old=path.read_bytes();new=(ROOT/name).read_bytes()
 if old!=new:before[name]=old;after[name]=new
for name in added:
 before[name]=b'';after[name]=(ROOT/name).read_bytes()
marker='<!-- PREPARED-ASSET-PIPELINE-20261104 -->'
end_marker='<!-- /PREPARED-ASSET-PIPELINE-20261104 -->'
for name in ('AGENTS.md','DEVELOPMENT_STATUS.md'):
 new=(ROOT/name).read_bytes();text=new.decode('utf-8')
 assert text.count(marker)==1 and text.count(end_marker)==1
 start=text.index(marker);end=text.index(end_marker)+len(end_marker)
 if text[end:end+2]=='\n\n':end+=2
 before[name]=(text[:start]+text[end:]).encode('utf-8');after[name]=new
owned=ROOT/'build/prepared-asset-pipeline-checkpoints'/str(time.time_ns())
source=owned/'source';verify=owned/'verify'
source.mkdir(parents=True);verify.mkdir()
assert owned.resolve().is_relative_to((ROOT/'build').resolve())
commands=[]
def git(folder,*arguments,output=None):
 command=['git','-C',str(folder),'-c','core.autocrlf=false',*arguments]
 result=subprocess.run(command,stdout=subprocess.PIPE if output is None else output,stderr=subprocess.PIPE,check=False)
 commands.append({'command':command,'exit_code':result.returncode,'stderr':result.stderr.decode(errors='replace')})
 assert result.returncode==0,result.stderr.decode(errors='replace')
for folder in (source,verify):
 git(folder,'init','-q')
 for name,data in before.items():
  if name in added:continue
  target=folder/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
git(source,'add','--','.')
for name,data in after.items():
 target=source/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
git(source,'add','--intent-to-add','--',*added)
patch=EVIDENCE/'task.patch'
with patch.open('wb') as output:git(source,'diff','--binary','--no-ext-diff',output=output)
git(verify,'apply','--check',str(patch))
git(verify,'apply',str(patch))
assert all((verify/name).read_bytes()==data for name,data in after.items())
git(verify,'apply','--reverse','--check',str(patch))
git(verify,'apply','--reverse',str(patch))
assert all(not (verify/name).exists() if name in added else (verify/name).read_bytes()==data for name,data in before.items())
report={'files':sorted(after),'binary_and_text_forward_exact':True,'binary_and_text_reverse_exact':True,
 'main_index_written':False,'generated_build_identity_and_project_version_excluded':True,
 'patch_bytes':patch.stat().st_size,'patch_sha256':hashlib.sha256(patch.read_bytes()).hexdigest(),
 'after_sha256':{name:hashlib.sha256(data).hexdigest() for name,data in after.items()},'commands':commands}
(EVIDENCE/'checkpoint.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print('Task-only source/binary patch passes forward, reverse and byte-exact content checks. Main index untouched.')
