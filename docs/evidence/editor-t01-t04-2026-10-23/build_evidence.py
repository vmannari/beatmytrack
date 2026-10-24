"""Build a scoped checkpoint without staging the shared worktree or its index."""
from pathlib import Path
import datetime
import difflib
import hashlib
import json
import re
import subprocess
import time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SOURCES = [
    'game/core/app.gd', 'game/backend/track_lifecycle.gd',
    'game/editor/editor_canvas.gd', 'game/editor/editor_world.gd',
    'game/editor/prepared_track_cache.gd', 'game/editor/road_pieces.gd',
    'game/editor/road_preparation.gd', 'game/editor/road_preparation_job.gd',
    'game/editor/road_sections.gd', 'game/editor/road_update.gd',
    'game/editor/editor_detail.gd', 'game/track/native_track_visual.gd',
    'game/track/visual_road_join.gd', 'game/track/grass_road_verge.gd',
    'game/track/bridge_presentation.gd', 'game/tests/test_editor_t01_t04.gd',
    'game/tests/fixtures/editor_t01_t04_before/canvas.gd',
    'game/editor/editor_detail.gd.uid', 'game/editor/road_update.gd.uid',
    'game/tests/test_editor_t01_t04.gd.uid',
    'game/tests/fixtures/editor_t01_t04_before/canvas.gd.uid',
]

def digest(data):
    return hashlib.sha256(data).hexdigest()

def read(path):
    return path.read_text(encoding='utf-8-sig')

def span(text, name):
    found = re.search(r'^(?:static )?func '+re.escape(name)+r'\(', text, re.M)
    assert found, name
    next_function = re.search(r'^(?:static )?func ', text[found.end():], re.M)
    end = found.end()+next_function.start() if next_function else len(text)
    return found.start(), end

def method(text, name):
    start, end = span(text, name)
    return text[start:end]

def replace_method(text, name, value):
    start, end = span(text, name)
    return text[:start]+value+text[end:]

observed = {}
current = {path: read(ROOT/path) for path in SOURCES}
for path in SOURCES:
    file = HERE/'before'/(path.replace('/', '__')+'.txt')
    if file.exists(): observed[path] = read(file)

# This preimage was not captured initially. Reconstruct just our added helper;
# preserve the already present concurrent paint-preparation changes verbatim.
prepared = 'game/editor/prepared_track_cache.gd'
base = dict(observed)
base[prepared] = replace_method(current[prepared], 'copy_track', '')

# The shared App and NativeTrackVisual gained cooperative race preparation and
# profiling from concurrent F04/F05 work during this task. Carry that foundation
# into the checkpoint base, so our patch neither claims nor reverses its work.
app_path = 'game/core/app.gd'
app = current[app_path]
for name in ['_save_draft', '_test_document', '_test_saved_draft',
             '_prepare_creator_test', '_compile_editor_with_masks']:
    app = replace_method(app, name, method(observed[app_path], name))
context = ('\t_practice_editor_context = {}\n'
           '\tif from_editor and screen == "create" and is_instance_valid(canvas) and canvas.document == document:\n'
           '\t\t_practice_editor_context = {"root":root_ui.get_instance_id(),"navigation":_navigation_generation,"mode":root_ui.process_mode}\n'
           '\t\troot_ui.process_mode = Node.PROCESS_MODE_DISABLED\n')
assert context in app
app = app.replace(context, '', 1)
app = app.replace('\telif not _resume_practice_editor(): _show_screen(', '\telse: _show_screen(', 1)
leave = method(app, '_leave_race').replace('\t_practice_editor_context = {}\n', '', 1)
app = replace_method(app, '_leave_race', leave)
app = replace_method(app, '_resume_practice_editor', '')
app = app.replace('var _practice_editor_context: Dictionary = {}\n', '', 1)
shared_cancel = ('\tif not _practice_editor_context.is_empty() and is_instance_valid(root_ui) and root_ui.get_instance_id() == _practice_editor_context.root:\n'
                 '\t\troot_ui.process_mode = _practice_editor_context.mode\n'
                 '\t_practice_editor_context = {}\n')
assert shared_cancel in app
app = app.replace(shared_cancel, '', 1)
assert '_practice_editor_context' not in app
base[app_path] = app

native_path = 'game/track/native_track_visual.gd'
native = observed[native_path]
build = method(current[native_path], 'build')
build = ''.join(line for line in build.splitlines(True)
                if '_tag_editor_children(' not in line
                and 'var editor_first:' not in line
                and 'editor_first = get_child_count()' not in line)
native = replace_method(native, 'build', build)
for name in ['_partition_bank_meshes', '_build_barriers']:
    native = replace_method(native, name, method(current[native_path], name))
profiling = ''.join(line for line in current[native_path].splitlines(True)
                    if line.startswith(('var profile_build:', 'var build_costs:')))
native = native.replace('var build_current: Callable\n', profiling+'var build_current: Callable\n', 1)
base[native_path] = native

base_folder = HERE/'checkpoint-base'
base_folder.mkdir(exist_ok=True)
patch = []
concurrent = []
manifest = []
for path in SOURCES:
    before = base.get(path, '')
    after = current[path]
    if path in base:
        (base_folder/path.replace('/', '__')).write_text(before, encoding='utf-8')
    patch.extend(difflib.unified_diff(before.splitlines(True), after.splitlines(True),
                                    fromfile='a/'+path if path in base else '/dev/null',
                                    tofile='b/'+path))
    if path in observed and observed[path] != before:
        concurrent.extend(difflib.unified_diff(observed[path].splitlines(True), before.splitlines(True),
                                              fromfile='a/'+path, tofile='b/'+path))
    manifest.append({'path':path, 'sha256':digest((ROOT/path).read_bytes()),
                     'checkpoint_base_lf_sha256':digest(before.encode()) if path in base else None,
                     'observed_before_lf_sha256':digest(observed[path].encode()) if path in observed else None})

patch_path = HERE/'task-only.patch'
patch_path.write_text(''.join(patch), encoding='utf-8')
(HERE/'concurrent-scoped-delta.patch').write_text(''.join(concurrent), encoding='utf-8')

# Verify the checkpoint with Git in a fresh disposable directory. Never stage,
# commit, reset or rewrite the owner's actual repository/index.
check_dir = ROOT/'build/editor-t01-t04'/('checkpoint-check-'+str(time.time_ns()))
check_dir.relative_to(ROOT)
check_dir.mkdir(parents=True)
for path, value in base.items():
    target = check_dir/path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(value, encoding='utf-8')
subprocess.run(['git','init','-q',str(check_dir)], check=True, capture_output=True)
subprocess.run(['git','-C',str(check_dir),'apply','--check',str(patch_path)], check=True, capture_output=True)
subprocess.run(['git','-C',str(check_dir),'apply',str(patch_path)], check=True, capture_output=True)
assert all(read(check_dir/path) == value for path, value in current.items())

dependencies = ['game/core/game.gd', 'game/editor/track_compiler.gd',
                'game/track/prepared_world_cache.gd','game/editor/placed_object_batches.gd',
                'game/track/native_track.gd','game/soundtrack/audio_world.gd',
                'game/platform/track_geometry/track_geometry.gdextension']
receipt = {
    'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'git_head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
    'godot':read(ROOT/'godot-version.txt').strip(),
    'sources':manifest,
    'integrated_dependencies':[{'path':p,'sha256':digest((ROOT/p).read_bytes())} for p in dependencies],
    'existing_winter_failure_checks':{
        'placed_object_batches_unchanged_from_git':subprocess.run(['git','diff','--quiet','HEAD','--','game/editor/placed_object_batches.gd'],cwd=ROOT).returncode == 0,
        'incremental_object_test_unchanged_from_git':subprocess.run(['git','diff','--quiet','HEAD','--','game/tests/test_editor_incremental_objects.gd'],cwd=ROOT).returncode == 0,
        'menu_audio_service_unchanged_from_git':subprocess.run(['git','diff','--quiet','HEAD','--','game/soundtrack/audio_world.gd'],cwd=ROOT).returncode == 0},
    'checkpoint':{'sha256':digest(patch_path.read_bytes()),'git_apply_check':True,'applied_files_match':True,
                  'base':'Captured preimages plus reconstructed concurrent App/NativeTrackVisual foundation; reconstructed prepared_track_cache preimage.',
                  'shared_integration':'Retained-editor process-mode cleanup in concurrent _discard_preparing_game is included in T02.',
                  'owner_index_untouched':True},
    'scope_limits':['No phone attachment check or physical-device test','No APK/export/deployment/live backend mutation',
                    'Canonical compiler/rules/schema/physics versions unchanged','Desktop debug results are not phone 60 FPS certification'],
}
(HERE/'source-manifest.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'files':len(manifest),'checkpoint_bytes':patch_path.stat().st_size,'git_apply_check':True}))
