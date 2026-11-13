"""Instrument only the disposable measured project and run bounded offline probes."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "build/game-profile-2026-11-12/snapshot/game"
WORK = ROOT / "build/loading-investigation-2026-11-12"
OUT = ROOT / "docs/evidence/loading-investigation-2026-11-12"
ENGINE = r"C:\apps\Godot 4.7.2\Godot_v4.7.2-stable_win64_console.exe"
NODE_HELPER = '''
func _deep_mark(label: String, data: Dictionary = {}) -> void:
	var trace: Node = Engine.get_main_loop().root.get_node_or_null("DeepTrace")
	if trace != null: trace.mark(label,data)
'''
STATIC_HELPER = '''
static func _deep_cost(label: String, usec: int) -> void:
	var trace: Node = Engine.get_main_loop().root.get_node_or_null("DeepTrace")
	if trace != null: trace.cost(label,usec)
'''


def replace(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f"Changed instrumentation anchor ({source.count(old)}): {old[:140]!r}")
    return source.replace(old, new)


def original(relative):
    path = WORK / "originals" / relative
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(PROJECT / relative, path)
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def wrap(source, signature, name, args, label, static=False, asynchronous=False):
    source = replace(source, signature, signature.replace(name+"(", "_deep_original_"+name+"("))
    result_type = "String" if signature.endswith("-> String:") else "bool" if signature.endswith("-> bool:") else ""
    call = ("await " if asynchronous else "") + "_deep_original_"+name+"("+args+")"
    lines = ["\n"+signature, "\tvar started: int = Time.get_ticks_usec()"]
    lines.append("\tvar result: "+result_type+" = "+call if result_type else "\t"+call)
    if static:
        lines.append('\t_deep_cost("'+label+'",Time.get_ticks_usec()-started)')
    else:
        lines += ['\tvar trace: Node = get_tree().root.get_node_or_null("DeepTrace")',
                  '\tif trace != null: trace.cost("'+label+'",Time.get_ticks_usec()-started)']
    if result_type:
        lines.append("\treturn result")
    return source + "\n".join(lines)+"\n"


def instrument():
    if not (PROJECT / "project.godot").is_file():
        raise SystemExit("The previous measured private project is unavailable; prepare a new coherent project first.")
    WORK.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    for parent in (WORK, PROJECT.parent.parent):
        (parent / ".keep").write_text("Active loading investigation; remove at completion.\n")
    changes = {}
    source = original("core/app.gd")
    anchor = "\t\t_install_feature_resource(path,load(path))"
    source = replace(source, anchor, '\t\t_deep_mark("feature_begin",{"path":path})\n'+anchor+'\n\t\t_deep_mark("feature_end",{"path":path})')
    changes["core/app.gd"] = source+NODE_HELPER
    source = original("rendering/graphics_preparation.gd")
    for signature, name, args in [
        ("static func context(view: Viewport, world: Node, camera: Camera3D) -> String:","context","view,world,camera"),
        ("static func geometry_key(node: GeometryInstance3D, materials: Dictionary = {}) -> String:","geometry_key","node,materials"),
        ("static func _material_key(material: Material, cache: Dictionary = {}) -> String:","_material_key","material,cache"),
    ]:
        source = wrap(source,signature,name,args,name,static=True)
    changes["rendering/graphics_preparation.gd"] = source+STATIC_HELPER
    source = original("race/world_render_preparation.gd")
    source = replace(source,"\twhile not pending.is_empty():\n",'\twhile not pending.is_empty():\n\t\t_deep_mark("world_batch_begin",{"pending":pending.size()})\n')
    source = replace(source,"\t\tvar began: int = Time.get_ticks_usec()",'\t\t_deep_mark("world_draw_begin",_deep_groups(submitted))\n\t\tvar began: int = Time.get_ticks_usec()')
    source = replace(source,"\t\tvar drawn: bool = await draw.call()",'\t\tvar drawn: bool = await draw.call()\n\t\t_deep_mark("world_draw_end",{"drawn":drawn})')
    source = replace(source,"\t\tcontext = Graphics.context(_view(),world,camera)",'\t\tcontext = Graphics.context(_view(),world,camera)\n\t\t_deep_mark("world_batch_end")')
    source += NODE_HELPER+'''
func _deep_groups(groups: Array) -> Dictionary:
	var result: Array = []
	for group: Dictionary in groups:
		var names: Array = []; var materials: Array = []
		for item: Dictionary in group.sources:
			var node: Object = item.node.get_ref()
			if not is_instance_valid(node): continue
			names.append(str(node.get_path()))
			if node is MeshInstance3D:
				for i: int in range(node.mesh.get_surface_count()):
					var material: Material = node.get_active_material(i)
					var description: String = material.get_class() if material != null else "none"
					if material is ShaderMaterial and material.shader != null: description += ":"+material.shader.resource_path
					if material is ShaderMaterial and material.has_meta("surface_dynamic_material"):
						var dynamic: ShaderMaterial = material.get_meta("surface_dynamic_material") as ShaderMaterial
						if dynamic != null and dynamic.shader != null: description += " [source="+dynamic.shader.resource_path+"]"
					if description not in materials: materials.append(description)
		result.append({"key":group.key,"nodes":names,"materials":materials})
	return {"groups":result}
'''
    changes["race/world_render_preparation.gd"] = source
    source = original("ui/rivalry_victory_car.gd")
    for anchor, label in [("\tworld.add_child(car)","podium_car_begin"),("\tvar weathering := VehicleWeathering.new()","podium_car_end"),("\tvar camera := Camera3D.new()","podium_studio_end"),("\tpresentation_ready = true","podium_ready")]:
        source = replace(source,anchor,'\tif podium_presentation: _deep_mark("'+label+'",{"widget":str(name)})\n'+anchor)
    source = wrap(source,"func _fit_camera() -> void:","_fit_camera","","podium_fit_camera")
    source = wrap(source,"func _refresh() -> void:","_refresh","","podium_refresh")
    # Append after the wrapper's cost recording; update scheduling only in this diagnostic copy.
    source += NODE_HELPER
    anchor = '\tif trace != null: trace.cost("podium_refresh",Time.get_ticks_usec()-started)'
    source = replace(source,anchor,anchor+'''
	if podium_presentation and is_instance_valid(viewport) and OS.has_environment("BMT_DEEP_PODIUM_COUNT"):
		var rank: int = int(str(name).get_slice("_",1))
		if rank > int(OS.get_environment("BMT_DEEP_PODIUM_COUNT")): viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
''')
    changes["ui/rivalry_victory_car.gd"] = source
    source = changes["ui/rivalry_victory_car.gd"]
    anchor = '\tif podium_presentation: _deep_mark("podium_studio_end",{"widget":str(name)})'
    source = replace(source,anchor,anchor+'''
	if podium_presentation:
		var mode: String = OS.get_environment("BMT_DEEP_LIGHTING")
		if mode == "no_sky":
			var environment: WorldEnvironment = world.get_node("PodiumReflectionEnvironment")
			environment.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
			environment.environment.sky = null
		elif mode == "no_rim": world.get_node("GarageRim").hide()
		elif mode == "no_shadows": world.get_node("GarageKey").shadow_enabled = false
''')
    changes["ui/rivalry_victory_car.gd"] = source
    source = original("core/game.gd")
    start = source.index("func _ready() -> void:")
    end = source.index("\nfunc ",start+1)
    body = source[start:end]
    for anchor,label in [("\ttrails = SkidTrails.new()","trails_begin"),("\tworld.add_child(trails)","trails_add"),("\tsand_dust = SandDustEffect.new()","particles_create_begin"),("\tworld.add_child(sand_dust)","particles_add_begin"),("\tsand_dust.prepare_track(native_track)","particles_track_begin"),("\tvehicle_audio = VehicleAudio.new()","audio_create_begin"),("\tadd_child(vehicle_audio)","audio_add_begin"),("\tvehicle_audio.configure(vehicle_id,handling,car)","audio_configure_begin")]:
        body = replace(body,anchor,'\t_deep_mark("'+label+'")\n'+anchor)
    for anchor,label in [("\tworld.add_child(trails)","trails_end"),("\tworld.add_child(sand_dust)","particles_add_end"),("\tsand_dust.prepare_track(native_track)","particles_track_end"),("\tadd_child(vehicle_audio)","audio_add_end"),("\tvehicle_audio.configure(vehicle_id,handling,car)","audio_configure_end")]:
        body = replace(body,anchor,anchor+'\n\t_deep_mark("'+label+'")')
    changes["core/game.gd"] = source[:start]+body+source[end:]+NODE_HELPER
    source = original("ui/weekly_rivalry_page.gd")
    source = replace(source,"func _build_content() -> void:\n",'func _build_content() -> void:\n\t_deep_mark("page_build_begin")\n')
    source = wrap(source,"func _build_content() -> void:","_build_content","","page_build_content")
    anchor = '\tif trace != null: trace.cost("page_build_content",Time.get_ticks_usec()-started)'
    source = replace(source,anchor,anchor+'\n\t_deep_mark("page_build_end")')
    changes["ui/weekly_rivalry_page.gd"] = source+NODE_HELPER
    source = original("core/features/race.gd")
    start = source.index("func run_start_race(app:")
    end = source.index("\nfunc run_race_installation_current(",start)
    body = source[start:end]
    hooks = [
        ("\tif not await app._await_selected_preparation(track,","selected_wait_begin"),
        ("\tvar daily_rules: RefCounted","selected_wait_end"),
        ("\tvar prepared_roads: Dictionary = {}","roads_begin"),
        ("\tapp.returning_to_editor = from_editor","roads_end"),
        ("\tapp.add_child(app.game)\n\tvar prepared_game: Node = app.game","game_begin"),
        ("\tif is_instance_valid(prepared_game.world_render_preparation):","game_end"),
        ("\t\tif not await prepared_game.world_render_preparation.prepare(","graphics_begin"),
        ("\tapp.game.opponent_ghost =","graphics_end"),
        ("\tvar prepared_finish: VehicleWeathering","finish_setup_begin"),
        ("\tvar bridge_preparation =","bridge_setup_begin"),
        ("\tvar trail_preparation =","trail_setup_begin"),
        ("\tvar preparation_started: int = Time.get_ticks_usec()","effects_begin"),
        ("\tvar effects_drawn: bool =","effects_return"),
        ("\tvar night_preparation: Dictionary =","finish_draw_return"),
        ("\tprepared_finish.end_render_warmup()","restore_finish"),
        ("\tif (finish_warmed or night_preparation.contexts > 0)","clean_draw_begin"),
        ("\tapp.game.set(\"weathering_prepared\", finish_drawn)","clean_draw_end"),
        ("\tapp._close_race_loading(loading_id)\n\n","race_end"),
    ]
    for anchor,label in hooks:
        indent = "\t\t" if anchor.startswith("\t\t") else "\t"
        body = replace(body,anchor,indent+'_deep_mark("'+label+'")\n'+anchor)
    changes["core/features/race.gd"] = source[:start]+body+source[end:]+NODE_HELPER
    for relative,source in changes.items():
        (PROJECT / relative).write_text(source,encoding="utf-8",newline="\n")
    shutil.copy2(ROOT / "game/tests/profile_deep_loading.gd",PROJECT / "tests/profile_deep_loading.gd")
    (OUT / "instrumentation.json").write_text(json.dumps({r:{"original_sha256":hashlib.sha256((WORK/"originals"/r).read_bytes()).hexdigest(),"instrumented_sha256":hashlib.sha256((PROJECT/r).read_bytes()).hexdigest()} for r in changes},indent=2))
    print("Instrumented private copy only: "+", ".join(changes))


def digest():
    result = hashlib.sha256()
    for p in sorted(PROJECT.rglob("*")):
        if p.is_file() and (".godot" not in p.parts or "imported" in p.parts):
            result.update(str(p.relative_to(PROJECT)).encode()); result.update(hashlib.sha256(p.read_bytes()).digest())
    return result.hexdigest()


def run(args):
    OUT.mkdir(parents=True,exist_ok=True)
    profile = WORK / "profiles" / (args.profile or args.name)
    for relative in ("roaming","local"): (profile/relative).mkdir(parents=True,exist_ok=True)
    captures = WORK / "captures" / args.name
    captures.mkdir(parents=True,exist_ok=True)
    (OUT/(args.name+"-configuration.json")).write_text(json.dumps(vars(args),indent=2))
    env = dict(os.environ,APPDATA=str(profile/"roaming"),LOCALAPPDATA=str(profile/"local"),BMT_API_URL="",BMT_DEV_AUTH_KEY="",BMT_LOADING_OUTPUT=str(OUT/(args.name+".json")),BMT_GRAPHICS_OUTPUT=str(captures),BMT_DEEP_PODIUM_COUNT=str(args.podium),BMT_DEEP_LIGHTING=args.lighting,BMT_DEEP_CONTACT="1" if args.contact else "0",BMT_DEEP_RETAIN_SCENE="1" if args.retain_scene else "0")
    wrapper = [sys.executable,str(ROOT/"scripts/run_no_crash_dialog.py"),"--",ENGINE]
    version = subprocess.check_output(wrapper+["--version"],text=True).strip()
    assert version == (ROOT/"godot-version.txt").read_text().strip()
    command = wrapper+["--path",str(PROJECT),"--audio-driver","Dummy","--position","10000,10000","--rendering-method",args.renderer,"--script","res://tests/profile_deep_loading.gd","--","--case="+args.case,"--theme="+args.theme]
    before = digest(); started = time.monotonic()
    path = OUT/(args.name+".log")
    with path.open("w",encoding="utf-8") as log:
        process = subprocess.Popen(command,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        (OUT/(args.name+"-process.json")).write_text(json.dumps(dict(pid=process.pid,command=command),indent=2))
        while process.poll() is None:
            time.sleep(0.3)
            text = path.read_text(encoding="utf-8",errors="replace")
            if "SCRIPT ERROR:" in text or time.monotonic()-started > 270:
                stopped = subprocess.run(["taskkill","/PID",str(process.pid),"/T","/F"],stdout=log,stderr=subprocess.STDOUT)
                if stopped.returncode:
                    print(json.dumps(dict(cleanup_required=True,pid=process.pid)),flush=True)
                    return 126
                break
        code = process.wait()
    after = digest()
    lines = path.read_text(encoding="utf-8",errors="replace").splitlines()
    diagnostics = list(dict.fromkeys(s for s in lines if s.startswith(("ERROR:","SCRIPT ERROR:","WARNING:","DEEP_FAIL"))))
    receipt = dict(command=command,engine=version,exit_code=code,seconds=round(time.monotonic()-started,3),before_sha256=before,after_sha256=after,unchanged=before==after,diagnostics=diagnostics)
    (OUT/(args.name+"-receipt.json")).write_text(json.dumps(receipt,indent=2))
    print(json.dumps(dict(name=args.name,**receipt)),flush=True)
    print("\n".join(lines[-4:]),flush=True)
    return int(code!=0 or before!=after or any(s.startswith("SCRIPT ERROR:") for s in diagnostics))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("action",choices=["instrument","run"])
    parser.add_argument("name",nargs="?",default="smoke")
    parser.add_argument("--case",choices=["rivalry","race"],default="rivalry")
    parser.add_argument("--renderer",default="gl_compatibility")
    parser.add_argument("--podium",type=int,default=3)
    parser.add_argument("--theme",default="pine")
    parser.add_argument("--profile",default="")
    parser.add_argument("--lighting",choices=["normal","no_sky","no_rim","no_shadows"],default="normal")
    parser.add_argument("--contact",action="store_true")
    parser.add_argument("--retain-scene",action="store_true")
    options = parser.parse_args()
    if options.action == "instrument": instrument()
    else: sys.exit(run(options))
