"""Keep a task-only patch while preserving the concurrent editor-properties work."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
BEFORE=OUT/"before"
paths=sorted(path.relative_to(BEFORE).as_posix() for path in BEFORE.rglob("*") if path.is_file())
added=["game/tests/fixtures/jump_palette_before/creator_catalog.gd.txt"]
paths += added
def replace_once(text,old,new):
    if text.count(old)!=1: raise ValueError("Expected exactly one task edit: "+old[:100])
    return text.replace(old,new,1)
patch=[]; sources={}
validation=ROOT/"tmp/jump-palette-patch-validation"
validation.mkdir(parents=True,exist_ok=True)
subprocess.run(["git","init","--quiet",str(validation)],check=True)
for name in paths:
    current=(ROOT/name).read_text(encoding="utf-8")
    base="" if name in added else (BEFORE/name).read_text(encoding="utf-8")
    if name=="game/core/app.gd":
        base=current
        base=replace_once(base,'object_browser.current = CreatorCatalog.jump_asset(canvas.stamp_jump_profile,str(document.theme)) if canvas.stamp_kind == "jump" else canvas.stamp_kind','object_browser.current = canvas.stamp_kind')
        base=replace_once(base,'\t\t\tvar stamp_label: String = CreatorCatalog.label(CreatorCatalog.jump_asset(canvas.stamp_jump_profile,str(document.theme))) if canvas.stamp_kind == "jump" else CreatorCatalog.label(canvas.stamp_kind)\n\t\t\teditor_status.text = stamp_label+', '\t\t\teditor_status.text = CreatorCatalog.label(canvas.stamp_kind)+')
        base=replace_once(base,'\tif CreatorCatalog.JUMP_ASSETS.has(kind): same_family = same_family and canvas.stamp_jump_profile == str(CreatorCatalog.JUMP_ASSETS[kind])\n','')
        base=replace_once(base,'\tvar jump_profile: String = str(CreatorCatalog.JUMP_ASSETS.get(kind,""))\n','')
        base=replace_once(base,'\tcanvas.stamp_kind="jump" if not jump_profile.is_empty() else kind','\tcanvas.stamp_kind=kind')
        base=replace_once(base,'\tif canvas.stamp_kind == "jump":\n\t\tcanvas.stamp_jump_profile = jump_profile if not jump_profile.is_empty() else JumpProfiles.default_for(str(document.theme))\n\t\tobject_browser.current = CreatorCatalog.jump_asset(canvas.stamp_jump_profile,str(document.theme))','\tif kind == "jump" and canvas.stamp_jump_profile not in JumpProfiles.IDS:\n\t\tcanvas.stamp_jump_profile = JumpProfiles.default_for(str(document.theme))')
        base=replace_once(base,'editor_world.warm_prop(canvas.stamp_kind,CreatorCatalog.default_scale(kind),canvas.stamp_container_color)','editor_world.warm_prop(kind,CreatorCatalog.default_scale(kind),canvas.stamp_container_color)')
    elif name=="game/editor/object_browser.gd":
        base=current
        base=replace_once(base,'\tif CreatorCatalog.JUMP_ASSETS.has(kind) and is_instance_valid(options): options.hide()\n','')
        base=replace_once(base,'(current == family[0] or current in family[3])','current in family[3]')
        base=replace_once(base,'var chosen: bool = current == asset[0] or current in asset[3]','var chosen: bool = current in asset[3]')
        base=replace_once(base,'\tif CreatorCatalog.JUMP_ASSETS.has(kind):\n\t\tchoose(kind)\n\t\treturn\n','')
    elif name=="game/editor/object_thumbnail.gd":
        base=current
        base=replace_once(base,'\tif CreatorCatalog.JUMP_ASSETS.has(kind): button.tooltip_text = title+" / Tap the track to place"\n','')
        base=replace_once(base,' if kind == "jump" or CreatorCatalog.JUMP_ASSETS.has(kind) else "")',' if kind == "jump" else "")')
        base=replace_once(base,'\tif CreatorCatalog.JUMP_ASSETS.has(kind):\n\t\tobject.kind = "jump"\n\t\tobject["jump_profile"] = str(CreatorCatalog.JUMP_ASSETS[kind])\n','')
        base=replace_once(base,' or CreatorCatalog.JUMP_ASSETS.has(kind) else Vector3(7,6.3,-10)',' else Vector3(7,6.3,-10)')
    saved=OUT/"patch-base"/name; saved.parent.mkdir(parents=True,exist_ok=True); saved.write_text(base,encoding="utf-8",newline="\n")
    target=validation/name; target.parent.mkdir(parents=True,exist_ok=True)
    if name in added:
        if target.exists(): target.unlink()
    else: target.write_text(base,encoding="utf-8",newline="\n")
    patch.extend(difflib.unified_diff(base.splitlines(keepends=True),current.splitlines(keepends=True),fromfile="/dev/null" if name in added else "a/"+name,tofile="b/"+name))
    sources[name]={"actual_sha256":hashlib.sha256((ROOT/name).read_bytes()).hexdigest(),"patch_base_lf_sha256":hashlib.sha256(base.encode()).hexdigest(),"task_start_sha256":None if name in added else hashlib.sha256((BEFORE/name).read_bytes()).hexdigest()}
file=OUT/"task.patch"; file.write_text("".join(patch),encoding="utf-8",newline="\n")
logs=[]
for args in (["--check"],[],["--reverse","--check"]):
    command=["git","-C",str(validation),"apply"]+args+[str(file)]
    result=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    logs.append({"command":command,"exit":result.returncode,"output":result.stdout})
    if result.returncode: raise RuntimeError(result.stdout)
for name in paths:
    assert (validation/name).read_text(encoding="utf-8")==(ROOT/name).read_text(encoding="utf-8"),name
(OUT/"patch-check.json").write_text(json.dumps(logs,indent=2),encoding="utf-8")
protected=json.loads((OUT/"protected-source-hashes.json").read_text())
changed=[name for name,digest in protected.items() if hashlib.sha256((ROOT/name).read_bytes()).hexdigest()!=digest]
report={"requirements":{"JPO01":"Each jump is its own named palette object and preview","JPO02":"One touch selects; repeat taps stay in placement with no style menu","JPO03":"Exact card selection, Recent, copy, undo, reload and saved object identity","Q01":"Native desktop evidence and a scoped review patch"},
 "source_files":sources,"commands":{path.stem:json.loads(path.read_text()) for path in OUT.glob('commands-*.json')},
 "results":{path.stem:json.loads(path.read_text()) for path in OUT.glob('results-*.json')},
 "concurrent_protected_source_changes":changed,"patch_checks":logs,
 "scope_note":"Four runtime files and two existing regressions. The patch base preserves concurrent properties, multi-selection, placement and thumbnail refinements. It is a documented current-context base with task edits removed, not a whole-tree historical snapshot. Task-start originals are retained separately.",
 "findings":["Existing sandbox certificate-store error remains in raw logs","Initial dynamic-array and stale tile-handle harness errors are retained","An intermediate concurrent properties change restored second-tap popup behavior; the explicit jump-card branch now retains direct placement","Broad object-browser assertions still assume the older properties UI; five gesture failures reproduce in paired task-start edited-source control, which has six failures total","App touch-cancellation failure reproduces unchanged in the paired control (141 checks, one failure)","Concurrent simulation/kart/hovercraft changes are preserved; no whole-tree canonical-freeze claim","Full parser: one concurrent parking-hall fixture failure in 1403 scripts; six targeted source/test parses pass","Small concurrent multi-selection/thumbnail refinements after the native run remain preserved; per-run hashes distinguish the actual tested source"],
 "acceptance":["Reload client/editor","Owner and physical-device appearance/input acceptance"],
 "device_test":False,"device_attachment_query":False,"cloud_mutation":False,"owner_save_mutation":False,"root_staging_commit_merge":False}
(OUT/"report.json").write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
print(f"{len(paths)} source/test files; patch applies, matches current sources, and reverse-checks")
