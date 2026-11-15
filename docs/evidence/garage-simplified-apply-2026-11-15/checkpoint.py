from pathlib import Path
import difflib,hashlib,json,subprocess,shutil
r=Path.cwd();w=r/'build/garage-simplified-apply-2026-11-15';d=r/'docs/evidence/garage-simplified-apply-2026-11-15'
files=['AGENTS.md','game/ui/garage_environment.gd','game/ui/garage_mesh_reduction.gd','game/ui/garage_mesh_reduction.gd.uid','game/tests/bake_garage_architecture.gd','game/tests/test_garage_environment_budget.gd','game/tests/test_garage_mesh_reduction.gd','game/tests/test_garage_mesh_reduction.gd.uid','game/export_presets.cfg','scripts/check_garage_workshop.py','scripts/test_garage_workshop.py','scripts/bake_garage_previews.gd','scripts/build_identity.ps1','scripts/run_garage_simplified.py','docs/GARAGE_SIMPLIFIED_APPLIED_2026_11_15.md']
fixture=w/'checkpoint';fixture.mkdir(exist_ok=True)
patch=[];receipt={}
for name in files:
 before=w/'before'/name;after=r/name
 old=before.read_text(encoding='utf-8-sig') if before.exists() else ''
 new=after.read_text(encoding='utf-8-sig')
 if old==new:continue
 target=fixture/name;target.parent.mkdir(parents=True,exist_ok=True)
 if before.exists():target.write_text(old,encoding='utf-8',newline='\n')
 patch.extend(difflib.unified_diff(old.splitlines(keepends=True),new.splitlines(keepends=True),fromfile='a/'+name if before.exists() else '/dev/null',tofile='b/'+name,n=3))
 receipt[name]={'before':hashlib.sha256(old.encode()).hexdigest() if before.exists() else None,'after':hashlib.sha256(new.encode()).hexdigest()}
 for side,text in [('before',old),('after',new)]:
  p=d/'source'/side/name;p.parent.mkdir(parents=True,exist_ok=True)
  if side=='after' or before.exists():p.write_text(text,encoding='utf-8',newline='\n')
p=d/'source-only.patch';p.write_text(''.join(patch),encoding='utf-8',newline='\n')
for flags in [ ['--check'],[],['--reverse','--check'],['--reverse'] ]:
 cmd=['git','apply','--whitespace=nowarn',*flags,'--directory='+fixture.relative_to(r).as_posix(),str(p.resolve())]
 result=subprocess.run(cmd,cwd=r,capture_output=True,text=True)
 assert result.returncode==0,(cmd,result.stdout,result.stderr)
 if flags==[]:
  for name,data in receipt.items():assert hashlib.sha256((fixture/name).read_text(encoding='utf-8-sig').encode()).hexdigest()==data['after'],name
for name,data in receipt.items():
 p=fixture/name
 if data['before'] is None:assert not p.exists(),name
 else:assert hashlib.sha256(p.read_text(encoding='utf-8-sig').encode()).hexdigest()==data['before'],name
(d/'checkpoint.json').write_text(json.dumps({'files':receipt,'normalized_forward_and_reverse_exact':True,'shared_index_used':False},indent=2))
print('Source checkpoint exact forward/reverse:',len(receipt),'files')
