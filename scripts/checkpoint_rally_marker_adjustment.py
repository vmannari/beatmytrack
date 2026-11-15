"""Reviewable task-only patch, without staging the shared workspace."""
import hashlib
import json
import subprocess
import run_rally_marker_adjustment as task

marker = 'RALLY-MARKER-ADJUSTMENT-20261115'
report = 'docs/RALLY_SIDE_MARKER_ADJUSTMENT_2026_11_15.md'
note = f'''<!-- {marker} -->
## Rally side reflectors lowered and moved rearward (2026-11-15)
RSM02: owner review moves both amber markers 25 mm down and 50 mm rearward from RSM01, retaining size, symmetry and stock/fitted fender clearance. Four retained-member recipe migrations, source/native views on both desktop renderers, prepared Compatibility views and App8/0 pass. Models/pictures were rebuilt, but repeated source fences reject continuing livery edits; final cache readiness remains unqualified. [Placement, views, commands and limits]({report}). Reload/owner appearance and phone acceptance remain; no device/export/backend/deployment/owner-save/process or shared-index action.
<!-- /{marker} -->

'''
trackers = ['AGENTS.md', 'DEVELOPMENT_STATUS.md', 'docs/PHASE_0_PLAN.md']
before = {'game/vehicle/compact_detail.gd': (task.WORK/'before/compact_detail.gd').read_bytes()}
for name in trackers:
    path = task.ROOT/name
    data = path.read_bytes()
    if data.startswith(note.encode()): data=data[len(note.encode()):]
    assert marker.encode() not in data
    before[name] = data
    path.write_bytes(note.encode()+data)
added = [report]
for folder in ['scripts','game/tests']:
    added += [p.relative_to(task.ROOT).as_posix() for p in (task.ROOT/folder).glob('*rally_marker_adjustment*')
              if p.suffix in ('.py','.gd','.uid')]
added += ['game/'+p.removeprefix('res://') for p in json.loads((task.OUT/'migration.json').read_text())]
names = sorted(set(before)|set(added))
after = {name:(task.ROOT/name).read_bytes() for name in names}
private = task.WORK/'source-checkpoint-final'
assert not private.exists()
private.mkdir(parents=True)
digest = lambda data: hashlib.sha256(data).hexdigest()
index = digest((task.ROOT/'.git/index').read_bytes())
def git(*args):
    process = subprocess.run(['git','-c','core.autocrlf=false','-c','core.whitespace=blank-at-eol,blank-at-eof,space-before-tab,cr-at-eol',*args],cwd=private,capture_output=True)
    assert process.returncode==0, process.stderr.decode(errors='replace')
    return process.stdout
def write(files):
    for name,data in files.items():
        path=private/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
git('init','--quiet');git('config','user.name','Local source checkpoint');git('config','user.email','checkpoint@invalid.local')
write(before);git('add','--all');git('commit','--quiet','-m','Task-start Rally marker source and documentation')
write(after);git('add','--all')
patch=git('diff','--cached','--binary','--full-index','HEAD')
(task.OUT/'source.patch').write_bytes(patch)
git('diff','--cached','--check')
git('apply','--check','--reverse',str(task.OUT/'source.patch'))
git('apply','--reverse',str(task.OUT/'source.patch'))
for name in names:
    path=private/name
    assert (path.read_bytes()==before[name]) if name in before else not path.exists(), name
git('apply',str(task.OUT/'source.patch'))
for name,data in after.items(): assert (private/name).read_bytes()==data,name
git('commit','--quiet','-m','RSM02 Lower Rally side markers and move them rearward')
assert digest((task.ROOT/'.git/index').read_bytes())==index
receipt={'files':names,'forward_byte_exact':True,'reverse_byte_exact':True,
         'main_index_unchanged_during_checkpoint':True,'commit':git('rev-parse','HEAD').decode().strip(),
         'patch_sha256':digest(patch),'derived_assets':'Rebuild after applying or reversing source patch.'}
(task.OUT/'source-checkpoint.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt,indent=2))
