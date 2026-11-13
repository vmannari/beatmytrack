"""Extract this pass's edits, retaining concurrent work in the comparison base."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess
import uuid

root=Path.cwd()
out=root/'docs/evidence/editor-ux-improvements-2026-10-28'
existing=['core/app.gd','editor/editor_canvas.gd','editor/object_browser.gd','editor/object_thumbnail.gd',
          'editor/editor_detail.gd','editor/editor_button.gd','editor/object_properties.gd',
          'editor/creator_prop_costs.gd','track/creator_prop_visual.gd','track/prop_structures.gd']
new=['game/editor/object_editing.gd','game/editor/overview_prop_models.gd','game/editor/surface_labels.gd',
     'game/tests/test_editor_ux_improvements.gd','game/tests/test_editor_prop_quality_2026_10_28.gd',
     'scripts/translations/editor_ux_2026_10_28.tsv']
patch=[]
manifest={}
excluded=[]
before_files={}
after_files={}
for relative in existing:
    name='game/'+relative
    saved=out/'scoped-before'/name
    if relative=='editor/object_properties.gd': saved=out/'scoped-before/object_properties.gd'
    if not saved.exists(): saved=out/'before'/name
    a=saved.read_text(encoding='utf-8-sig').splitlines(True)
    b=(root/name).read_text(encoding='utf-8-sig').splitlines(True)
    base=[]
    for tag,i,j,k,l in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes():
        if tag=='equal': base.extend(b[k:l]);continue
        old=''.join(a[i:j]);current=''.join(b[k:l])
        function=''
        for line in a[:i+1]:
            if line.startswith('func '): function=line.split('(',1)[0][5:]
        owned=True
        kept=[]
        if relative=='core/app.gd':
            allowed=['_editor','_editor_hint','_update_editor_save_state','_build_editor_tools','_delete_selection',
                     '_set_object_rotation','_duplicate_object','_refresh_editor','_apply_editor_writes','_start_race',
                     '_build_paint_tools','_unhandled_key_input','_build_surface_toolbar']
            owned=function in allowed or 'var editor_guidance:' in current or 'editor_view = {' in current
            if function=='_build_editor_tools' and 'var stamp_label:' in current: owned=False
            if function=='_choose_object': owned=current=='\tcanvas.multi_select = false\n'
            if function=='_editor' and 'editor_session.prime(document)' in current:
                kept=['\teditor_session.prime(document)\n']
        elif relative=='editor/editor_canvas.gd':
            owned='proposed.hidden_scenery' not in current and 'var errors: Array[String] = RoadPieces.validate(trial)' not in current and function!='flip_start_line'
        elif relative=='editor/object_browser.gd':
            owned=not ('JUMP_ASSETS' in current or 'properties_button.custom_minimum_size' in current or 'properties_button.text' in current)
        elif relative=='editor/object_properties.gd': owned=function!='_layout'
        if owned: base.extend(a[i:j]);base.extend(kept)
        else:
            base.extend(b[k:l]);excluded.append({'path':name,'before_line':i+1,'function':function})
    before_files[name]=''.join(base)
    after_files[name]=''.join(b)
for name in new:
    before_files[name]=''
    after_files[name]=(root/name).read_text(encoding='utf-8-sig')
for name,old in before_files.items():
    current=after_files[name]
    if old==current: continue
    patch.append('diff --git a/'+name+' b/'+name+'\n')
    if name in new:patch.append('new file mode 100644\n')
    patch.extend(difflib.unified_diff(old.splitlines(True),current.splitlines(True),fromfile='/dev/null' if name in new else 'a/'+name,tofile='b/'+name,n=3))
    manifest[name]={'before_sha256':hashlib.sha256(old.encode()).hexdigest(),'after_sha256':hashlib.sha256(current.encode()).hexdigest()}
patch_path=out/'task-only.patch'
patch_path.write_text(''.join(patch),encoding='utf-8',newline='\n')
isolated=root/'build/editor-ux-improvements-2026-10-28'/('checkpoint-'+uuid.uuid4().hex[:10])
isolated.mkdir(parents=True)
for name,contents in before_files.items():
    if name in new:continue
    p=isolated/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(contents,encoding='utf-8',newline='\n')
commands=[]
def run(args,cwd):
    result=subprocess.run(args,cwd=cwd,capture_output=True,text=True)
    commands.append({'command':args,'cwd':str(cwd),'exit':result.returncode,'output':result.stdout+result.stderr})
    assert result.returncode==0,commands[-1]
run(['git','init','--quiet'],isolated)
run(['git','apply','--check',str(patch_path)],isolated)
run(['git','apply',str(patch_path)],isolated)
for name,contents in after_files.items(): assert (isolated/name).read_text(encoding='utf-8')==contents,name
run(['git','apply','--reverse','--check',str(patch_path)],isolated)
run(['git','apply','--reverse','--check',str(patch_path)],root)
result={'files':manifest,'excluded_concurrent_edits':excluded,'commands':commands,'exact_isolated_after':True,
        'patch_sha256':hashlib.sha256(patch_path.read_bytes()).hexdigest()}
(out/'checkpoint.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps({'files':len(manifest),'excluded_concurrent_edits':len(excluded),'checks':'forward, exact result, reverse, current reverse'}))
