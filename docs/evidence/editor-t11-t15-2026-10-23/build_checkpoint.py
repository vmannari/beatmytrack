"""Build a task-only Git checkpoint without touching the shared index."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess
import sys
import uuid

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[2]
BEFORE = EVIDENCE/'before'
WORK = ROOT/'build/editor-t11-t15'/('checkpoint-'+uuid.uuid4().hex[:12])
WORK.mkdir(parents=True)
EXPECTED, BASE, VERIFY = WORK/'expected', WORK/'base', WORK/'verify'
BASE.mkdir()

FILES = [
    'AGENTS.md','DEVELOPMENT_STATUS.md','docs/PHASE_0_PLAN.md',
    'docs/EDITOR_T11_T15_2026_10_23.md','docs/schemas/creator-track-v5.schema.json',
    'game/core/app.gd','game/editor/commit_queue.gd','game/editor/editor_canvas.gd',
    'game/editor/editor_world.gd','game/editor/road_pieces.gd','game/editor/track_document.gd','game/editor/creator_limits.gd',
    'game/editor/editor_session.gd','game/editor/editor_session.gd.uid',
    'game/editor/editor_gesture.gd','game/editor/editor_gesture.gd.uid',
    'game/editor/road_piece_catalog.gd','game/editor/road_piece_catalog.gd.uid',
    'game/track/creator_prop_visual.gd','game/track/prop_geometry.gd','game/track/native_track.gd',
    'game/ui/track_catalog.gd','game/persistence/track_library.gd','game/tests/test_road_pieces.gd','game/tests/test_app.gd',
    'game/tests/test_catalog.gd','game/tests/test_race_results.gd','game/tests/test_editor_workflow.gd','game/tests/test_editor_t01_t04.gd',
    'game/tests/test_editor_t11_t15.gd','game/tests/test_editor_t11_t15.gd.uid',
]
for name in ['run.ps1','check_renders.py','build_checkpoint.py','build_report.py','schema-check.json','root-receipt.txt']:
    FILES.append(EVIDENCE.relative_to(ROOT).as_posix()+'/'+name)


def run(*args, cwd=BASE):
    done = subprocess.run(args,cwd=cwd,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    if done.returncode:
        raise RuntimeError((args,done.returncode,done.stdout.decode('utf-8','replace'),done.stderr.decode('utf-8','replace')))
    return done.stdout


def read(path): return path.read_text(encoding='utf-8')
def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(value,encoding='utf-8',newline='\n')
def digest(value): return hashlib.sha256(value).hexdigest()


index = ROOT/'.git/index'
index_before = digest(index.read_bytes()) if index.is_file() else None
final = {name:read(ROOT/name) for name in FILES}
for name in ['game/core/app.gd','game/editor/commit_queue.gd','game/editor/editor_canvas.gd','game/editor/road_pieces.gd']:
    write(EXPECTED/name,read(BEFORE/name))
run(sys.executable,str(EVIDENCE/'edit_architecture.py'),cwd=EXPECTED)
canvas_path = EXPECTED/'game/editor/editor_canvas.gd'
write(canvas_path,read(canvas_path).replace('_navigation_only = false; panning = false; active_pointer = -99','gesture.clear(); panning = false; active_pointer = -99',1))

# Recover only our App edits. Current unrelated methods, rotation controls,
# population/preview changes and fields stay in the foundation.
for name in ['app','editor_canvas','road_pieces']:
    relative = 'game/core/app.gd' if name == 'app' else 'game/editor/'+name+'.gd'
    if name == 'road_pieces':
        write(EXPECTED/relative,read(EXPECTED/relative).replace('static func create(kind: String, position: Vector2, heading: float = 0.0, width: float = 10.0) -> Dictionary:\n','static func create(kind: String, position: Vector2, heading: float = 0.0, width: float = 10.0) -> Dictionary:\n\tif kind not in KINDS: return {}\n',1))
    inverse = ''.join(difflib.unified_diff(read(EXPECTED/relative).splitlines(True),read(BEFORE/relative).splitlines(True),fromfile='a/'+relative,tofile='b/'+relative,n=3))
    write(EVIDENCE/('inverse-own-'+name+'.patch'),inverse)
receipt = read(EVIDENCE/'root-receipt.txt')
prefixes = {'AGENTS.md':'## Editor T11–T15 and current import policy override (2026-10-23)\n'+receipt+'\n',
            'DEVELOPMENT_STATUS.md':receipt+'\n','docs/PHASE_0_PLAN.md':receipt+'\n'}
for name in FILES:
    prior = BEFORE/name
    if name in prefixes:
        assert final[name].count(prefixes[name]) == 1,name
        base = final[name].replace(prefixes[name],'',1)
    elif name in ['game/core/app.gd','game/editor/editor_canvas.gd','game/editor/road_pieces.gd']: base = final[name]
    elif name == 'docs/schemas/creator-track-v5.schema.json':
        base = final[name].replace('        "pine",\n','        "pine",\n        "coast",\n',1)
    elif name == 'game/editor/track_document.gd':
        base = final[name].replace('\tif not data.get("schema") is String or data.schema != SCHEMA:\n\t\treturn ["Unsupported track format. Import a current creator-track-v5 file."]\n','',1)
        base = base.replace('\tif data.has("automatic_scenery")','\tif data.get("schema") != SCHEMA:\n\t\terrors.append("This track format is not supported.")\n\tif data.has("automatic_scenery")',1)
        base = base.replace('not data.get("theme") is String or data.theme not in THEMES','not data.get("theme") is String or (data.theme not in THEMES and data.theme != "coast")',1)
    elif name == 'game/ui/track_catalog.gd':
        base = final[name].replace('not data.get("schema") is String or data.schema != TrackDocument.SCHEMA','data.get("schema") != TrackDocument.SCHEMA',1)
        base = base.replace('data.get("theme") not in TrackDocument.THEMES:','data.get("theme") not in TrackDocument.THEMES and data.get("theme") != "coast":',1)
    elif name == 'game/persistence/track_library.gd':
        base = final[name].replace('last_error = "This file is too large; creator tracks are at most %d KB." % (TrackDocument.MAX_BYTES/1024)','last_error = "This file is too large; creator tracks are at most 512 KB."',1)
        base = base.replace('last_error = "This creator track exceeds %d KB." % (TrackDocument.MAX_BYTES/1024)','last_error = "This creator track exceeds 512 KB."',1)
    elif name == 'game/track/native_track.gd':
        base = final[name].replace('not data is Dictionary or not data.get("schema") is String or data.schema != "surface-grid-v2"',
                                  'not data is Dictionary or data.get("schema", "") not in ["surface-grid-v1", "surface-grid-v2"]',1)
        base = base.replace('get_meta(&\"creator_queries\") if has_meta(&\"creator_queries\") else null','get_meta(&\"creator_queries\",null)',1)
        base = base.replace('\t# Trusted current native data only. Older imports are never upgraded.\n\tif not data.get("schema") is String or data.schema != "surface-grid-v2": return null',
                            '\t# Trusted native data only. Creator imports are validated and compiled first.',1)
    elif prior.is_file():
        base = read(prior)
        if name == 'game/track/creator_prop_visual.gd':
            # Concurrent geometry work clarified this comment; it is not ours.
            base = base.replace('These are assembly vertex ends','These are triangle-corner ends')
    else: continue
    write(BASE/name,base)
write(BASE/'.gitattributes','* text eol=lf\n')
run('git','init','-q')
run('git','config','core.autocrlf','false')
for name in ['app','editor_canvas','road_pieces']:
    run('git','apply','--check',str(EVIDENCE/('inverse-own-'+name+'.patch')))
    run('git','apply',str(EVIDENCE/('inverse-own-'+name+'.patch')))

foundation = {}
for name in FILES:
    path = BASE/name
    if path.is_file():
        data = path.read_bytes(); foundation[name] = digest(data)
        target = EVIDENCE/'checkpoint-base'/name
        target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
run('git','add','-A')
run('git','-c','user.name=Codex','-c','user.email=codex@local.invalid','commit','-qm','Task foundation with concurrent changes preserved')
base_commit = run('git','rev-parse','HEAD').decode().strip()
for name,value in final.items(): write(BASE/name,value)
run('git','add','-A')
whitespace = run('git','diff','--cached','--check').decode()
patch = run('git','diff','--cached','--binary','--full-index','--no-ext-diff')
(EVIDENCE/'task-only.patch').write_bytes(patch)
run('git','worktree','add','--detach',str(VERIFY),'HEAD')
run('git','apply','--check',str(EVIDENCE/'task-only.patch'),cwd=VERIFY)
run('git','apply',str(EVIDENCE/'task-only.patch'),cwd=VERIFY)
for name,value in final.items():
    assert read(VERIFY/name) == value,name
    assert read(ROOT/name) == value,('concurrent change during checkpoint',name)
run('git','-c','user.name=Codex','-c','user.email=codex@local.invalid','commit','-qm','Editor T11-T15: transactions, safe prop preparation and current imports')
commit = run('git','rev-parse','HEAD').decode().strip()
index_after = digest(index.read_bytes()) if index.is_file() else None
result = {'files':FILES,'foundation':foundation,'foundation_commit':base_commit,'task_commit':commit,
          'isolated_repository':str(BASE),'patch_bytes':len(patch),'patch_sha256':digest(patch),
          'git_apply_check':True,'git_apply_readback_exact_normalized_text':True,
          'added_whitespace_check':whitespace,'shared_index_unchanged':index_before == index_after,
          'concurrent_preserved':['App methods/fields/rotation/population controls','CreatorPropVisual comment','other NativeTrack methods','other root-document updates'],
          'note':'Patch foundation includes prior editor fixes and current concurrent work; no shared index or owner commit was changed.'}
write(EVIDENCE/'checkpoint.json',json.dumps(result,indent=2)+'\n')
print(json.dumps({k:result[k] for k in ['task_commit','patch_bytes','patch_sha256','git_apply_check','shared_index_unchanged']}))
