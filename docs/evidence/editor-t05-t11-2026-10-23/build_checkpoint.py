"""Build a reviewable task patch without touching the owner's Git index."""
from pathlib import Path
import difflib
import hashlib
import json
import re
import subprocess
import tempfile

OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
PRODUCTION = [
    'game/core/app.gd', 'game/editor/editor_canvas.gd',
    'game/editor/editor_world.gd', 'game/editor/cache_bytes.gd',
    'game/editor/material_preparation.gd', 'game/editor/object_thumbnail.gd',
    'game/editor/placed_object_batches.gd', 'game/editor/road_piece_work.gd',
    'game/editor/road_preparation.gd', 'game/editor/spline_borders.gd',
    'game/track/native_track_visual.gd', 'game/track/creator_prop_visual.gd',
    'game/track/prepared_world_cache.gd',
    'game/persistence/document_read_cache.gd',
    'game/persistence/document_encoding.gd',
]
TESTS = ['test_editor_workflow', 'test_editor_review_fixes',
         'test_editor_remaining', 'test_editor_incremental_objects',
         'test_editor_placement_latency', 'test_editor_t01_t04',
         'test_editor_v2', 'test_editor_retirement', 'test_start_line', 'test_app']
NEW = ['game/editor/'+name+'.gd' for name in
       ['editor_history', 'commit_queue', 'editor_memory', 'spatial_bounds']]
NEW += ['game/tests/test_editor_t05_t11.gd']
NEW += [p.relative_to(ROOT).as_posix() for p in
        (ROOT/'game/tests/fixtures/editor_t05_t11_before').glob('*.gd')]
NEW += [name+'.uid' for name in list(NEW)]


def method(source, name):
    match = re.search(r'(?m)^(?:static )?func '+re.escape(name)+r'\(', source)
    assert match, name
    end = re.search(r'(?m)^(?:static )?func ', source[match.end():])
    return source[match.start():match.end()+end.start() if end else len(source)]


base = {}
final = {}
for name in PRODUCTION + ['game/tests/'+name+'.gd' for name in TESTS]:
    before = OUT/'before'/name.replace('/', '__')
    assert before.exists(), name
    base[name] = before.read_text(encoding='utf-8-sig')
    final[name] = (ROOT/name).read_text(encoding='utf-8-sig')

# Revert only this task's methods/fields from the current shared App. This
# carries concurrent challenge and retained-menu work into the foundation.
app = 'game/core/app.gd'
observed_app = base[app]
owned = ['_notification','_exit_tree','_process','_objects_only_edit','_editor',
         '_update_editor_save_state','_update_test_access','_remember','_undo','_redo',
         '_apply_editor_writes','_apply_editor_commits','_flush_editor_writes',
         '_save_draft','_share_dialog','_save_track_now']
foundation = final[app]
for name in owned:
    current_method = method(foundation,name)
    old_method = '' if name == '_apply_editor_commits' else method(observed_app,name)
    foundation = foundation.replace(current_method,old_method,1)
for line in [
    'const EDITOR_HISTORY = preload("res://editor/editor_history.gd")\n',
    'var editor_memory = preload("res://editor/editor_memory.gd").new()\n',
    'var _editor_exiting: bool = false\n',
    'var editor_commits = preload("res://editor/commit_queue.gd").new()\n',
    'var editor_validation_document: Dictionary = {}\n',
    'var editor_validation_errors: Array[String] = []\n',
    'var editor_workflow_presentation: Dictionary = {}\n',
]:
    assert foundation.count(line) == 1, line
    foundation = foundation.replace(line,'',1)
base[app] = foundation
concurrent = {}
for name in re.findall(r'(?m)^func (\w+)\(',foundation):
    value = method(foundation,name)
    try: old = method(observed_app,name)
    except AssertionError: old = ''
    if old != value: concurrent[name] = hashlib.sha256(value.encode()).hexdigest()
# The shared race partitioner also changed concurrently. Preserve it by
# reversing only our editor installation/tag/cache additions.
native = 'game/track/native_track_visual.gd'
observed_native = base[native]
foundation_native = final[native]
for name in ['_budget_install','trim_editor_cache']:
    current_method = method(foundation_native,name)
    old_method = '' if name == 'trim_editor_cache' else method(observed_native,name)
    foundation_native = foundation_native.replace(current_method,old_method,1)
marker = '\tstage.set_meta("editor_transient",true)\n'
assert foundation_native.count(marker) == 1
foundation_native = foundation_native.replace(marker,'',1)
base[native] = foundation_native
concurrent_native = {}
for name in re.findall(r'(?m)^(?:static )?func (\w+)\(',foundation_native):
    value = method(foundation_native,name)
    try: old = method(observed_native,name)
    except AssertionError: old = ''
    if old != value: concurrent_native[name] = hashlib.sha256(value.encode()).hexdigest()
for name in ['AGENTS.md', 'DEVELOPMENT_STATUS.md']:
    final[name] = (ROOT/name).read_text(encoding='utf-8-sig')
    source = final[name]
    if name == 'AGENTS.md':
        first = source.index('## Track editor T05 to T11 fixes override')
        last = source.index('\n## ',first+1)+1
    else:
        first = source.index('2026-10-23 T05-T11/R01/Q01:')
        last = source.index('\n\n',first)+2
    base[name] = source[:first]+source[last:]
for name in NEW + ['docs/EDITOR_T05_T11_2026_10_23.md']:
    assert (ROOT/name).exists(), name
    base[name] = ''
    final[name] = (ROOT/name).read_text(encoding='utf-8-sig')

work = Path(tempfile.mkdtemp(prefix='editor-t05-t11-checkpoint-', dir=ROOT/'build'))
subprocess.run(['git', 'init', '-q', str(work)], check=True)
patch = []
manifest = {}
for name in sorted(final):
    if base[name] == final[name]: continue
    patch.append('diff --git a/'+name+' b/'+name+'\n')
    if not base[name]: patch.append('new file mode 100644\n')
    patch += difflib.unified_diff(base[name].splitlines(True), final[name].splitlines(True),
                                fromfile='a/'+name if base[name] else '/dev/null', tofile='b/'+name)
    if base[name]:
        archived_base = OUT/'checkpoint-base'/name
        archived_base.parent.mkdir(parents=True, exist_ok=True)
        archived_base.write_text(base[name], encoding='utf-8', newline='\n')
        target = work/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(base[name], encoding='utf-8', newline='\n')
    raw = (ROOT/name).read_bytes()
    manifest[name] = {'sha256':hashlib.sha256(raw).hexdigest(), 'bytes':len(raw)}
patch_path = OUT/'task-only.patch'
patch_path.write_text(''.join(patch), encoding='utf-8', newline='\n')
checked = subprocess.run(['git', '-C', str(work), 'apply', '--check', str(patch_path)], capture_output=True, text=True)
assert checked.returncode == 0, checked.stderr
subprocess.run(['git', '-C', str(work), 'apply', str(patch_path)], check=True)
for name in manifest:
    assert (work/name).read_text(encoding='utf-8') == final[name], name
# Check newly added source lines, preserving pre-existing documentation spacing.
trailing = [(name, line[1:]) for name in manifest
            for line in difflib.unified_diff(base[name].splitlines(), final[name].splitlines())
            if line.startswith('+') and not line.startswith('+++') and line[1:].rstrip(' \t') != line[1:]]
assert not trailing, trailing
(OUT/'source-manifest.json').write_text(json.dumps({'files':manifest,'concurrent_app_methods':concurrent,'concurrent_native_methods':concurrent_native}, indent=2))
receipt = {'files':len(manifest),'patch_bytes':patch_path.stat().st_size,
           'patch_sha256':hashlib.sha256(patch_path.read_bytes()).hexdigest(),
           'git_apply_check':checked.returncode, 'git_apply_and_readback':'exact',
           'trailing_whitespace':trailing,'owner_index_changed':False,
           'concurrent_app_methods_preserved':list(concurrent),'concurrent_native_methods_preserved':list(concurrent_native),'isolated_check_directory':str(work)}
(OUT/'checkpoint.json').write_text(json.dumps(receipt, indent=2))
print(json.dumps(receipt, indent=2))
