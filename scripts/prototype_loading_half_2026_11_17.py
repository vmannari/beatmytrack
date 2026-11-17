"""Reversible source-only prototypes in the private loading experiment project."""
import json
import re
import sys
from pathlib import Path
from loading_half_review_2026_11_17 import ROOT, PROJECT, OUT, replace_file, digest

ORIGINALS = OUT / "originals"

def edit(relative, transform):
    path = PROJECT/relative
    backup = ORIGINALS/relative
    if not backup.exists():
        backup.parent.mkdir(parents=True,exist_ok=True)
        backup.write_bytes(path.read_bytes())
    original = backup.read_text(encoding="utf-8")
    candidate = transform(original)
    if candidate != original:
        replace_file(path,candidate)
        return relative

def restore():
    if ORIGINALS.exists():
        for path in ORIGINALS.rglob("*"):
            if path.is_file(): replace_file(PROJECT/path.relative_to(ORIGINALS),path.read_bytes())

def lazy_app(source):
    lines=[]
    for line in source.splitlines():
        if line.startswith("\t"):
            line=line.replace("preload(","load(")
            line=re.sub(r'\bvar (\w+)\s*:=',r'var \1: Variant =',line)
            line=line.replace(": TrackSession",": RefCounted").replace(": VehicleSimulation",": RefCounted")
            line=line.replace("TrackCompiler.compile(",'load("res://editor/track_compiler.gd").compile(')
        lines.append(line)
    return "\n".join(lines)+"\n"

def contracts(source):
    # Resolve heavy compiler/simulation helpers when actually called.
    paths={"TrackCompiler":"res://editor/track_compiler.gd", "VehicleSimulation":"res://vehicle/vehicle_simulation.gd"}
    lines=[]
    for line in source.splitlines():
        if line.startswith("\t") and not line.lstrip().startswith("#"):
            for name,path in paths.items():
                line=re.sub(r'\b'+name+r'\.', 'load("'+path+'").',line)
            line=re.sub(r'\bvar (\w+)\s*:=',r'var \1: Variant =',line)
            line=line.replace(": VehicleSimulation",": RefCounted")
        lines.append(line)
    return "\n".join(lines)+"\n"

def lazy_audio(source):
    source=source.replace("var progress := DrivingScoreProgress.new()",'''var _progress: RefCounted
var progress: RefCounted:
	get:
		if _progress == null: _progress = load("res://soundtrack/driving_score_progress.gd").new()
		return _progress''')
    source=source.replace("var personal_reference := ScorePaceReference.new()", "var personal_reference: RefCounted")
    source=source.replace("var rival_reference := ScorePaceReference.new()", "var rival_reference: RefCounted")
    source=source.replace("ScorePaceReference.new()", 'load("res://soundtrack/score_pace_reference.gd").new()')
    source=source.replace(": TrackSession", ": RefCounted")
    source=source.replace("ancestor is TouchControls", '_review_touch_controls(ancestor)')
    source+='''
func _review_touch_controls(node: Node) -> bool:
	var script: Script = node.get_script()
	while script != null:
		if script.resource_path == "res://ui/touch_controls.gd": return true
		script = script.get_base_script()
	return false
'''
    return source

def race_split():
    relative="core/features/race.gd"
    original=(PROJECT/relative).read_text(encoding="utf-8")
    starts=list(re.finditer(r'^func (\w+)\(',original,re.M))
    core={"run_load_daily_limits","_daily_ticket","run_retry_daily_race","run_prepare_metadata_race",
          "run_start_race_road_job","run_start_race","run_race_installation_current","run_discard_preparing_game",
          "run_prepare_night_lighting","run_edit_here","run_leave_race","run_resume_practice_editor",
          "run_retry_race","run_prepare_race_rating"}
    result=original[:starts[0].start()]
    for i,match in enumerate(starts):
        body=original[match.start():starts[i+1].start() if i+1<len(starts) else len(original)]
        if match[1] in core:
            result+=body
        else:
            signature=body.splitlines()[0].replace("results: RaceResults","results: Control")
            params=signature[signature.index("(")+1:signature.rindex(")")]
            args=[p.strip().split(":")[0].strip() for p in params.split(",") if p.strip()]
            asynchronous="await " in body
            result+=signature+"\n\t"+("return " if "-> void:" not in signature else "")+("await " if asynchronous else "")+'app._feature_resource("res://core/features/race.gd").'+match[1]+"("+",".join(args)+")\n\n"
    target=PROJECT/"core/features/race_start_prototype.gd"
    replace_file(target,result)
    old='res://core/features/race.gd'; new='res://core/features/race_start_prototype.gd'
    edit("core/app.gd",lambda s:s.replace(old,new))
    print(json.dumps(dict(path=str(target.relative_to(PROJECT)),lines=len(result.splitlines()),core=sorted(core))))

def support_disk(source):
    source=source.replace('static func read(key: String) -> Dictionary:\n', 'static func read(key: String) -> Dictionary:\n\t_review_restore(key)\n')
    anchor='\tentries[key] = {"value":value,"bytes":cost}\n\tbytes += cost\n\tguard.unlock()'
    assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\n\t_review_save(key,value)')
    return source+'''
static var review_disk_hits: int = 0
static var review_disk_restoring: bool = false
static func _review_digest(data: PackedByteArray) -> String:
	var hash := HashingContext.new(); hash.start(HashingContext.HASH_SHA256); hash.update(data)
	return hash.finish().hex_encode()
static func _review_restore(key: String) -> void:
	guard.lock()
	var present: bool = entries.has(key)
	var expected_generation: int = generation
	guard.unlock()
	if present: return
	var name: String = key.sha256_text()+".support"
	var path: String = "user://cache/support-prototype/"+name
	if "--bundle" in OS.get_cmdline_user_args() and FileAccess.file_exists("res://assets/prepared_half_prototype/support-prototype/"+name):
		path = "res://assets/prepared_half_prototype/support-prototype/"+name
	var file := FileAccess.open_compressed(path,FileAccess.READ,FileAccess.COMPRESSION_ZSTD)
	if file == null: return
	if file.get_length() > MAX_BYTES or file.get_length() <= 0: return
	var packet: Variant = file.get_var(false)
	if not packet is Dictionary or packet.get("key","") != key or not packet.get("value") is Dictionary: return
	if packet.get("source","") != FileAccess.get_sha256("res://track/road_surface_height.gd"): return
	if packet.get("sha","") != _review_digest(var_to_bytes(packet.value)): return
	var value: Dictionary = packet.value
	if not value.get("floors") is Array or not value.get("bins") is Dictionary: return
	for floor: Variant in value.floors:
		if not floor is PackedVector2Array: return
	review_disk_restoring = true
	write(key,value,expected_generation)
	review_disk_restoring = false
	review_disk_hits += 1
static func _review_save(key: String, value: Dictionary) -> void:
	if review_disk_restoring: return
	var directory: String = "user://cache/support-prototype"
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return
	var file := FileAccess.open_compressed(directory.path_join(key.sha256_text()+".support"),FileAccess.WRITE,FileAccess.COMPRESSION_ZSTD)
	if file != null: file.store_var({"key":key,"value":value,"source":FileAccess.get_sha256("res://track/road_surface_height.gd"),"sha":_review_digest(var_to_bytes(value))},false)
'''

def bundled_world(source):
    def section(text, name, transform):
        found=re.search(r'^static func '+name+r'\(',text,re.M)
        end=text.find('\nstatic func ',found.start()+1)
        if end<0: end=len(text)
        return text[:found.start()]+transform(text[found.start():end])+text[end:]
    source=source.replace('static func read_entry(id: String) -> Dictionary:\n', '''static func read_entry(id: String) -> Dictionary:
	if "--bundle" in OS.get_cmdline_user_args():
		var bundled: Dictionary = _read_entry(id,"res://assets/prepared_half_prototype/prepared_worlds_v1")
		if not bundled.is_empty(): return bundled
''')
    source=section(source,'_read_entry',lambda s:s.replace('_read_entry(id: String)', '_read_entry(id: String, read_directory: String = "")').replace('\n\tvar manifest:', '\n\tif read_directory.is_empty(): read_directory = directory\n\tvar manifest:').replace('_manifest(id)','_manifest(id,read_directory)').replace('directory.path_join','read_directory.path_join').replace('_payload_valid(manifest)','_payload_valid(manifest,read_directory)'))
    source=section(source,'_manifest',lambda s:s.replace('_manifest(id: String)', '_manifest(id: String, read_directory: String = "")').replace('\n\tif directory.is_empty()', '\n\tif read_directory.is_empty(): read_directory = directory\n\tif read_directory.is_empty()').replace('directory.path_join','read_directory.path_join'))
    source=section(source,'_payload_valid',lambda s:s.replace('_payload_valid(manifest: Dictionary)', '_payload_valid(manifest: Dictionary, read_directory: String = "")').replace('\n\tvar path:', '\n\tif read_directory.is_empty(): read_directory = directory\n\tvar path:').replace('directory.path_join','read_directory.path_join'))
    return source

def bundled_numeric(source, family):
    if family=='roads':
        for name in ['read_entry','read_arrays']:
            found=re.search(r'^static func '+name+r'\(',source,re.M)
            end=source.find('\nstatic func ',found.start()+1)
            body=source[found.start():end]
            suffix='.res' if name=='read_entry' else '.arrays'
            anchor='\tvar path: String = directory.path_join(id+"'+suffix+'")'
            assert body.count(anchor)==1
            body=body.replace(anchor,anchor+'\n\tif "--bundle" in OS.get_cmdline_user_args() and FileAccess.file_exists("res://assets/prepared_half_prototype/road_meshes_v1/"+id+"'+suffix+'"):\n\t\tpath = "res://assets/prepared_half_prototype/road_meshes_v1/"+id+"'+suffix+'"')
            source=source[:found.start()]+body+source[end:]
    else:
        anchor='\tvar file := FileAccess.open(directory.path_join(id+".gates"),FileAccess.READ)'
        assert source.count(anchor)==1
        source=source.replace(anchor,'\tvar read_path: String = directory.path_join(id+".gates")\n\tif "--bundle" in OS.get_cmdline_user_args() and FileAccess.file_exists("res://assets/prepared_half_prototype/checkpoint_layouts_v1/"+id+".gates"):\n\t\tread_path = "res://assets/prepared_half_prototype/checkpoint_layouts_v1/"+id+".gates"\n\tvar file := FileAccess.open(read_path,FileAccess.READ)')
    return source

def bootstrap_audio(source):
    source=lazy_audio(source)
    for old,new in [('LocalRecords','RefCounted'),('VehicleState','RefCounted'),('NativeTrack','Resource'),('HandlingConfig','Resource')]:
        source=source.replace(': '+old,': '+new)
    source=source.replace('var wobble_gain: float = 1.0 - progress.wobble * 0.07', 'var wobble_gain: float = 1.0 - (float(_progress.wobble) if _progress != null else 0.0) * 0.07')
    return source

def record_boundary(source):
    source=contracts(source)
    for old,new in [('NativeTrack','Resource'),('HandlingConfig','Resource')]:
        source=source.replace(': '+old,': '+new)
    lines=[]
    for line in source.splitlines():
        if line.startswith('\t'): line=line.replace('preload(','load(')
        lines.append(line)
    return '\n'.join(lines)+'\n'

def lazy_methods(source):
    lines=[]
    for line in source.splitlines():
        if line.startswith('\t'):
            line=line.replace('preload(','load(')
            line=re.sub(r'\bvar (\w+)\s*:=',r'var \1: Variant =',line)
        lines.append(line)
    return '\n'.join(lines)+'\n'

mode=sys.argv[1]
if mode=="restore":
    restore(); print("Restored private prototypes")
elif mode=="app-lazy":
    print(json.dumps([edit("core/app.gd",lazy_app)]))
elif mode=="contracts":
    changed=[]
    for directory in ["backend","persistence","ui","core"]:
        for path in (PROJECT/directory).rglob("*.gd"):
            if "features" in path.parts or path.name=="game.gd": continue
            text=path.read_text(encoding="utf-8")
            if re.search(r'\b(TrackCompiler|VehicleSimulation)\.',text):
                relative=path.relative_to(PROJECT).as_posix()
                result=edit(relative,contracts)
                if result: changed.append(result)
    print(json.dumps(changed))
elif mode=="audio-lazy":
    print(json.dumps([edit("soundtrack/audio_world.gd",lazy_audio)]))
elif mode=="race-split":
    race_split()
elif mode=="prepared-data":
    changed=[edit('track/road_support_cache.gd',support_disk),edit('track/prepared_world_disk_cache.gd',bundled_world),
             edit('track/road_mesh_disk_cache.gd',lambda s:bundled_numeric(s,'roads')),
             edit('race/checkpoint_layout_disk_cache.gd',lambda s:bundled_numeric(s,'gates'))]
    print(json.dumps(changed))
elif mode=="bootstrap-boundaries":
    print(json.dumps([edit('soundtrack/audio_world.gd',bootstrap_audio),edit('persistence/local_records.gd',record_boundary)]))
elif mode=="backend-boundary":
    print(json.dumps([edit('backend/backend_client.gd',lazy_methods)]))
else:
    raise SystemExit("Unknown prototype "+mode)
