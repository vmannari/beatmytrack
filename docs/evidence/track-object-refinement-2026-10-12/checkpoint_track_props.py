from pathlib import Path
import json, hashlib, subprocess, re, shutil
root=Path.cwd()
ev=root/'docs/evidence/track-object-refinement-2026-10-12'
work=root/'build/track_object_refinement'
repo=work/'checkpoint-repo'
repo.mkdir(parents=True,exist_ok=False)
old=['game/track/creator_prop_visual.gd','game/track/native_track_visual.gd','game/track/hazard_visual.gd','game/track/hazard.gdshader','game/track/winter_scenery.gd','game/editor/object_thumbnail.gd','game/tests/test_moving_prop_presentation.gd','AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']
new=['game/track/prop_geometry.gd','game/track/prop_nature.gd','game/track/prop_equipment.gd','game/track/prop_structures.gd','game/editor/prop_preview_shadow.gdshader','game/tests/test_prop_refinement.gd','game/tests/capture_prop_refinement.gd','game/tests/profile_prop_refinement.gd']
new += [x+'.uid' for x in new]
new += ['docs/TRACK_OBJECT_REFINEMENT.md']
current={name:(root/name).read_text(encoding='utf-8') for name in old+new}
before={name:(ev/'before'/name.replace('/','__')).read_text(encoding='utf-8') for name in old}
entry=(work/'status-entry.txt').read_text(encoding='utf-8')
for name in ['DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md']:
    assert current[name].count(entry)==1,(name,'missing owned report entry')
    before[name]=current[name].replace(entry,'',1)
s=current['AGENTS.md']
a=s.index('## Track object and palette refinement override (2026-10-12)')
b=s.index('## ',a+3)
before['AGENTS.md']=s[:a]+s[b:]
# Only the owned prop functions and revision bump enter this diff. Road edits
# made concurrently remain in the shared workspace, outside this checkpoint.
name='game/track/native_track_visual.gd'
s=before[name]
s=re.sub(r'const VERSION: String = "track-kit-\d+"', 'const VERSION: String = "track-kit-154"',s,count=1)
a=s.index('func _build_placed_objects('); b=s.index('func _tyre(',a)
part=s[a:b]
part=part.replace('\tif count > 0:\n\t\ttool.generate_normals()', '\tif count > 0:\n\t\ttool.generate_normals()\n\t\ttool.index()',1)
part=part.replace('\t\tink_tool.generate_normals()', '\t\tink_tool.generate_normals()\n\t\tink_tool.index()',1)
part=part.replace('\t\tstack.generate_normals()', '\t\tstack.generate_normals()\n\t\tstack.index()',1)
part=part.replace('\t\t# Small roof seams and foliage use their silhouettes, not intersecting ink hulls.', '\t\t# Small roof seams and foliage use their silhouettes, not intersecting ink hulls.\n\t\tmaterial.vertex_color_is_srgb = true',1)
part=part.replace('\t\tink_material.vertex_color_use_as_albedo = true','\t\tink_material.vertex_color_use_as_albedo = true\n\t\tink_material.vertex_color_is_srgb = true',1)
part=part.replace('\t\trubber.vertex_color_use_as_albedo = true','\t\trubber.vertex_color_use_as_albedo = true\n\t\trubber.vertex_color_is_srgb = true',1)
now=current[name]
actual=now[now.index('func _build_placed_objects('):now.index('func _tyre(')]
assert part==actual,'Concurrent edits inside placed-object function require a separate scoped audit.'
s=s[:a]+part+s[b:]
for start,end in [('func _tyre(','func _colored_box('),('func _finish_prop_mesh(','func update_light_props(')]:
    a=s.index(start); b=s.index(end,a)
    na=now.index(start); nb=now.index(end,na)
    s=s[:a]+now[na:nb]+s[b:]
owned_after=dict(current); owned_after[name]=s
for name in old:
    target=repo/name; target.parent.mkdir(parents=True,exist_ok=True); target.write_text(before[name],encoding='utf-8',newline='\n')
def git(*args):
    return subprocess.run(['git','-C',str(repo),*args],check=True,capture_output=True).stdout
git('init','-q'); git('config','user.name','Codex'); git('config','user.email','codex@local.invalid'); git('config','core.autocrlf','false')
git('add','--all'); git('commit','-q','-m','Baseline: track objects before refinement')
base=git('rev-parse','HEAD').decode().strip()
for name in old+new:
    target=repo/name; target.parent.mkdir(parents=True,exist_ok=True); target.write_text(owned_after[name],encoding='utf-8',newline='\n')
git('add','--all'); git('commit','-q','-m','Refine every track prop and shared model palette')
head=git('rev-parse','HEAD').decode().strip()
(ev/'track-objects.patch').write_bytes(git('diff','--binary',base,head,'--'))
(ev/'review-stat.txt').write_bytes(git('show','--stat','--oneline','HEAD'))
ledger={'baseline_commit':base,'refinement_commit':head,'checkpoint_repository':'build/track_object_refinement/checkpoint-repo','scope':'Only owned changes; native road sections are composed from the captured pre-task baseline. Main Git HEAD/index untouched.','files':[]}
for name in old+new:
    row={'path':name,'workspace_sha256':hashlib.sha256((root/name).read_bytes()).hexdigest(),'checkpoint_sha256':hashlib.sha256((repo/name).read_bytes()).hexdigest()}
    if name in before: row['before_text_sha256']=hashlib.sha256(before[name].encode()).hexdigest()
    ledger['files'].append(row)
(ev/'checkpoint.json').write_text(json.dumps(ledger,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'baseline':base,'checkpoint':head,'changed_files':len(old+new),'patch':str(ev/'track-objects.patch')},indent=2))
