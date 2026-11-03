extends SceneTree
## Compare actual showroom hood selection, keeping startup outside the samples.
const Meshes=preload("res://vehicle/electric_reference_mesh.gd")
const Kits=preload("res://vehicle/modular_car_kits.gd")
var output: String="res://../docs/evidence/volt-hood-loading-2026-11-03/profile.json"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var fallback: bool="--fallback" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output=argument.trim_prefix("--output=")
	Kits.enabled=not fallback
	if "--raw-hoods" in OS.get_cmdline_user_args():
		preload("res://vehicle/electric_kits.gd")._hood_mesh_bank_checked=true
		preload("res://vehicle/electric_kits.gd")._hood_mesh_bank_valid=false
	root.size=Vector2i(960,540)
	var report: Dictionary={"renderer":RenderingServer.get_current_rendering_method(),"fallback":fallback,"cars":{}}
	for id: String in ["electric","compact","kart","forklift","hovercraft"]:
		var room:=CarShowroom.new()
		room.vehicle_id=id
		room.read_only=false
		room.garage_mode=true
		room.customisation=VehicleCustomisation.defaults()
		room.size=Vector2(root.size)
		root.add_child(room)
		while not room.showroom_ready: await process_frame
		var samples: Array=[]
		for round_index: int in range(2):
			for option: Array in VehicleCustomisation.options("hood",id).slice(1):
				var parts: Dictionary=VehicleCustomisation.defaults()
				parts.hood=option[0]
				var hits: int=Kits.hits
				var meshes: int=Meshes.meshes.size()
				var started: int=Time.get_ticks_usec()
				room.apply_customisation(parts,true)
				var apply_us: int=Time.get_ticks_usec()-started
				room.finish_kit_transition()
				room.showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
				room.reflections.request_draw()
				await process_frame
				if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
				var value: Dictionary={"option":option[0],"round":round_index,"apply_ms":apply_us/1000.0,"draw_ready_ms":(Time.get_ticks_usec()-started)/1000.0,"prepared_hit":Kits.hits>hits,"new_mesh_keys":Meshes.meshes.size()-meshes}
				samples.append(value)
				print("HOOD_SAMPLE ",id," ",JSON.stringify(value))
			report.cars[id]=samples
		room.free()
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("HOOD_PROFILE_COMPLETE ",output)
	quit()
