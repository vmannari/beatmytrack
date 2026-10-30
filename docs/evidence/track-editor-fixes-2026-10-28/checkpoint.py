from pathlib import Path
import difflib
import hashlib
import json
import re
import shutil
import subprocess

root = Path.cwd()
out = root / 'docs/evidence/track-editor-fixes-2026-10-28'
before = out / 'before'
target = out / 'checkpoint-after'
patch = ''
inventory = []
def function(lines, position):
    for line in reversed(lines[:position+1]):
        found = re.match(r'func (\w+)\(', line)
        if found: return found[1]
    return ''

def scoped(path, old, current):
    a, b = old.splitlines(True), current.splitlines(True)
    result = list(a)
    for tag, i, j, k, l in reversed(difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes()):
        if tag == 'equal': continue
        left, right = ''.join(a[i:j]), ''.join(b[k:l])
        name = function(b,k)
        keep = False
        if path == 'game/core/app.gd':
            keep = name in ['_change_piece','_commit_selection','_set_document_value','_commit_editor_previews','_resolve_editor_previews','_share_dialog','_open_object_population']
            if name == '_editor':
                if 'editor_session.prime(document)' in right:
                    right = '\teditor_session.prime(document)\n'; keep = True
                elif 'EditorRaceLighting' in right:
                    right = right[right.index('\tif str(document.theme) == "night_city":'):]; keep = True
        else:
            keep = name in ['admit','_gui_input','confirm_piece','confirm_paint','flip_start_line','piece_accept_rect','_move_road']
            if 'func admit(' in right: keep = True
            if name == 'cancel_gesture':
                if '_rollback_navigation_edit()' in right:
                    right = '\t_rollback_navigation_edit()\n'; keep = True
                elif 'edit_finished.emit()' in left: keep = True
            if name == '_begin' and 'proposed.hidden_scenery' in right: keep = True
            if name == '_place' and ('admit(' in right or ('practice_start' in right and 'pose' in right) or (not right and left == '\t\t_start_edit()\n')): keep = True
            if name == '_end' and ('admit(' in right or 'authoring_admission.gd' in right): keep = True
        if keep: result[i:j] = right.splitlines(True)
    return ''.join(result)

paths = ['game/core/app.gd','game/editor/editor_canvas.gd','game/editor/editor_world.gd','game/editor/editor_history.gd','game/editor/editor_session.gd','game/editor/editor_memory.gd','game/editor/road_sections.gd','game/race/world_render_preparation.gd','native/track_geometry/track_geometry.cpp','native/track_geometry/road_geometry.hpp','native/track_geometry/PROVENANCE.md']
paths += ['game/editor/authoring_admission.gd','native/track_geometry/editor_streams.hpp','scripts/translations/track_editor_review_fixes.tsv']
paths += ['game/tests/'+name+'.gd' for name in ['test_editor_review_items','test_editor_admission_bytes','test_editor_graphics_preparation','test_editor_streams','test_editor_shipping_parse','profile_editor_fixed_history','profile_editor_fixed_preparation','profile_editor_phases','review_editor_fixed_items']]
for relative in paths:
    current = (root / relative).read_text(encoding='utf-8')
    old_path = before / relative
    old = old_path.read_text(encoding='utf-8') if old_path.exists() else ''
    final = scoped(relative,old,current) if relative in ['game/core/app.gd','game/editor/editor_canvas.gd'] else current
    destination = target / relative
    destination.parent.mkdir(parents=True,exist_ok=True)
    destination.write_text(final,encoding='utf-8',newline='\n')
    patch += 'diff --git a/'+relative+' b/'+relative+'\n'
    if not old: patch += 'new file mode 100644\n'
    patch += ''.join(difflib.unified_diff(old.splitlines(True),final.splitlines(True),fromfile='a/'+relative if old else '/dev/null',tofile='b/'+relative))
    inventory.append(dict(path=relative,before_sha256=hashlib.sha256(old.encode()).hexdigest() if old else None,checkpoint_sha256=hashlib.sha256(final.encode()).hexdigest(),current_sha256=hashlib.sha256((root/relative).read_bytes()).hexdigest(),concurrent_hunks_excluded=final != current))
for language in ['de','es','fi','fr','it','ja','ko','nb','nl','pt_BR','sv']:
    relative = 'game/localization/'+language+'.po'
    old = (before/relative).read_text(encoding='utf-8')
    final = (root/relative).read_text(encoding='utf-8')
    # Only the two task messages; other catalogue edits can continue independently.
    additions = []
    for block in final.split('\n\n'):
        if 'msgid "Race lighting"' in block or 'msgid "Confirm or discard the pending previews before sharing this circuit."' in block:
            if block not in old: additions.append(block.strip()+'\n')
    task_final = old + ''.join('\n'+block for block in additions)
    patch += 'diff --git a/'+relative+' b/'+relative+'\n'
    patch += ''.join(difflib.unified_diff(old.splitlines(True),task_final.splitlines(True),fromfile='a/'+relative,tofile='b/'+relative))
    paths.append(relative)
(out/'task.patch').write_text(patch,encoding='utf-8',newline='\n')
(out/'checkpoint-sources.json').write_text(json.dumps(inventory,indent=2),encoding='utf-8')
check = root / 'build/track-editor-fixes-2026-10-28/patch-check'
for relative in paths:
    source = before/relative
    if source.exists():
        dest = check/relative; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(source,dest)
command = ['git','apply','--check','--verbose','--whitespace=error-all','--unsafe-paths','--directory='+str(check).replace('\\','/'),str(out/'task.patch')]
result = subprocess.run(command,capture_output=True,text=True,encoding='utf-8')
(out/'patch-check.log').write_text(result.stdout+result.stderr,encoding='utf-8')
print(json.dumps(dict(command=command,exit=result.returncode,files=len(paths))))
assert result.returncode == 0
assert result.stderr.count('Checking patch ') == len(paths), 'Every patch file must actually be checked'
