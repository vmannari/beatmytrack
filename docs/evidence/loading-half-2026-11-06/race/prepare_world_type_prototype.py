"""Isolated annotation-only graph experiment; original scenes/guards unchanged."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import time

evidence = Path(__file__).resolve().parent
root = evidence.parents[3]
baseline = root/'build/loading-half-20261106/frozen-1793996701250524100/game'
owned = root/'build/loading-half-20261106'/('world-type-prototype-'+str(time.time_ns()))
fixture = '''extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func run() -> void:
    var target: String = "res://ui/garage_preview_cache.gd"
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--target="): target = argument.trim_prefix("--target=")
    var observed: Array[String] = ["vehicle/car_visual.gd","ui/car_showroom.gd","ui/showroom_studio.gd","editor/editor_memory.gd","track/prepared_world_cache.gd","track/native_track_visual.gd","vehicle/vehicle_models.gd","vehicle/compact_detail.gd","vehicle/electric_car_model.gd","vehicle/hovercraft_model.gd","vehicle/compact_kits.gd","ui/garage_thumbnail_studio.gd"]
    var before: Dictionary = {}
    for path: String in observed: before[path] = ResourceLoader.has_cached("res://"+path)
    var start: int = Time.get_ticks_usec()
    var resource: Script = load(target)
    var elapsed: int = Time.get_ticks_usec()-start
    checks += 1
    if resource == null: failures += 1
    var after: Dictionary = {}
    for path: String in observed: after[path] = ResourceLoader.has_cached("res://"+path)
    var output: String = OS.get_environment("BMT_LOADING_OUTPUT")
    checks += 1
    if output.is_empty(): failures += 1
    else: FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"target":target,"load_us":elapsed,"before":before,"after":after},"  "))
    print("WORLD_TYPE_GRAPH ",checks," checks, ",failures," failures; ",target," ",elapsed," us")
    quit(1 if failures else 0)
'''

def junction(source, destination):
    assert source.resolve().is_relative_to(root.resolve())
    assert destination.absolute().is_relative_to(owned.absolute())
    quote = lambda path: "'"+str(path).replace("'","''")+"'"
    subprocess.run(['powershell','-NoProfile','-Command',
                    'New-Item -ItemType Junction -Path '+quote(destination)+' -Target '+quote(source)+' | Out-Null'],check=True)

projects = {}
for arm in ['control','candidate']:
    game = owned/arm/'game'
    game.mkdir(parents=True)
    for source in baseline.iterdir():
        if source.name in ['assets','.godot','android']:
            continue
        if source.is_file(): shutil.copyfile(source,game/source.name)
        else: shutil.copytree(source,game/source.name)
    junction(baseline/'assets',game/'assets')
    (game/'.godot').mkdir()
    for filename in ['global_script_class_cache.cfg','uid_cache.bin','extension_list.cfg']:
        if (baseline/'.godot'/filename).exists(): shutil.copyfile(baseline/'.godot'/filename,game/'.godot'/filename)
    junction(baseline/'.godot/imported',game/'.godot/imported')
    junction(root/'native',game.parent/'native')
    (game/'tests/profile_world_type_graph.gd').write_bytes(fixture.encode('utf-8'))
    projects[arm] = str(game)
path = Path(projects['candidate'])/'track/prepared_world_cache.gd'
source = path.read_bytes()
assert source.count(b'visual: NativeTrackVisual') == 2
path.write_bytes(source.replace(b'visual: NativeTrackVisual',b'visual: Node3D'))
receipt = dict(projects=projects,baseline=str(baseline),changes={
    'track/prepared_world_cache.gd':{
        'before':hashlib.sha256(source).hexdigest(),
        'after':hashlib.sha256(path.read_bytes()).hexdigest()}},
    guards_changed=False,shipping_files_changed=False,
    prepared_assets='Read-only junction to the immutable original baseline asset library')
(evidence/'world-type-prototype.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf-8')
print(json.dumps(receipt))
