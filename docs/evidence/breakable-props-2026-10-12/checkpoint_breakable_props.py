from pathlib import Path
import re, json, hashlib, subprocess, shutil
root=Path.cwd(); ev=root/'docs/evidence/breakable-props-2026-10-12'; work=root/'build/breakable_props'
repo=work/'checkpoint-repo'; repo.mkdir(parents=True,exist_ok=False)
old=['AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md','game/editor/creator_catalog.gd','game/editor/creator_objects.gd','game/editor/track_compiler.gd','game/vehicle/light_props.gd','game/vehicle/vehicle_state.gd','game/vehicle/vehicle_simulation.gd','game/persistence/handling_recorder.gd','game/track/native_track_visual.gd','game/track/creator_prop_visual.gd','game/track/prop_equipment.gd','game/tests/test_kerbs.gd','game/tests/test_tracks.gd','game/tests/test_creator.gd','game/tests/test_winter_compiler_contract.gd','game/tests/fixtures/compiler_raster.json','docs/schemas/creator-track-v5.schema.json','scripts/dev.ps1','backend/deploy/stage_verifier.py','backend/tests/test_verifier.py','backend/tests/fixtures/verified_oval.json']
new=['game/vehicle/breakable_props.gd','game/track/breakable_prop_visual.gd','game/tests/test_breakable_props.gd','game/tests/test_breakable_contract.gd','game/tests/capture_breakable_props.gd']
new += [x+'.uid' for x in new]; new += ['docs/BREAKABLE_PROPS.md']
current={name:(root/name).read_text(encoding='utf-8') for name in old+new}
before={name:(ev/'before'/name.replace('/','__')).read_text(encoding='utf-8') for name in old}
entry=(work/'status-entry.txt').read_text(encoding='utf-8')
for name in ['DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
 assert current[name].count(entry)==1,(name,'owned report missing')
 before[name]=current[name].replace(entry,'',1)
s=current['AGENTS.md']; a=s.index('## Hay bales and breakable crates override (2026-10-12)'); b=s.index('## ',a+3); before['AGENTS.md']=s[:a]+s[b:]
# Keep latest concurrent road/shader work as context. Remove only the owned
# placed-soft-object block and presenter; its single cache revision is isolated.
name='game/track/native_track_visual.gd'; s=current[name]; original=before[name]
a=s.index('\t\tif object.kind in CreatorCatalog.SOFT:'); b=s.index('\t\tif object.kind in ["tree","broadleaf"',a)
oa=original.index('\t\tif object.kind in CreatorCatalog.SOFT:'); ob=original.index('\t\tif object.kind in ["tree","broadleaf"',oa)
s=s[:a]+original[oa:ob]+s[b:]
a=s.index('func update_light_props('); b=s.index('func _build_kerbs(',a)
oa=original.index('func update_light_props('); ob=original.index('func _build_kerbs(',oa)
s=s[:a]+original[oa:ob]+s[b:]
version=re.search(r'const VERSION: String = "track-kit-(\d+)"',s)
s=s[:version.start()]+f'const VERSION: String = "track-kit-{int(version.group(1))-1}"'+s[version.end():]
before[name]=s
# Runtime and test fixture bodies remain byte-equivalent as JSON except pins.
fixture='backend/tests/fixtures/verified_oval.json'
a=json.loads(before[fixture]); b=json.loads(current[fixture]); a.pop('expected_manifest'); b.pop('expected_manifest'); assert a==b
# Strip unrelated concurrent edits from schema/dev context by removing only
# the additions introduced here, retaining every previous requirement.
name='docs/schemas/creator-track-v5.schema.json'; before[name]=current[name].replace('              "hay_bale",\n','',1)
name='scripts/dev.ps1'
s=current[name]
for line in ["    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_breakable_props.gd') 'breakable-props-tests.log'\n", "    Invoke-Checked $script:godot @('--headless', '--path', $projectRoot, '--script', 'res://tests/test_breakable_contract.gd') 'breakable-props-contract.log'\n"]:
 assert line in s; s=s.replace(line,'',1)
before[name]=s
for name in old:
 p=repo/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(before[name],encoding='utf-8',newline='\n')
def git(*args): return subprocess.run(['git','-C',str(repo),*args],check=True,capture_output=True).stdout
git('init','-q'); git('config','user.name','Codex'); git('config','user.email','codex@local.invalid'); git('config','core.autocrlf','false'); git('add','--all'); git('commit','-q','-m','Baseline: movable props before hay and crate destruction')
base=git('rev-parse','HEAD').decode().strip()
for name in old+new:
 p=repo/name; p.parent.mkdir(parents=True,exist_ok=True); p.write_text(current[name],encoding='utf-8',newline='\n')
git('add','--all'); git('commit','-q','-m','Add progressive hay bales and breakable wooden crates')
head=git('rev-parse','HEAD').decode().strip(); git('diff','--check',base,head)
(ev/'breakable-props.patch').write_bytes(git('diff','--binary',base,head,'--'))
(ev/'review-stat.txt').write_bytes(git('show','--stat','--oneline','HEAD'))
ledger={'baseline_commit':base,'feature_commit':head,'repository':'build/breakable_props/checkpoint-repo','scope':'Only owned changes; latest concurrent road/schema/validation context preserved. Main Git branch/index untouched.','files':[]}
for name in old+new:
 row={'path':name,'workspace_sha256':hashlib.sha256((root/name).read_bytes()).hexdigest(),'checkpoint_sha256':hashlib.sha256((repo/name).read_bytes()).hexdigest()}
 if name in before: row['before_text_sha256']=hashlib.sha256(before[name].encode()).hexdigest()
 ledger['files'].append(row)
(ev/'checkpoint.json').write_text(json.dumps(ledger,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'baseline':base,'feature':head,'files':len(old+new),'main_repository_mutations':False},indent=2))
