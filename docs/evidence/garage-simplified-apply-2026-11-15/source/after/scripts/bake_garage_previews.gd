extends SceneTree
## Run with the pinned engine and a graphical renderer. Native game assets only.
const Transaction = preload("res://tests/support/asset_bake_transaction.gd")
var bake_errors := preload("res://tests/support/asset_bake_errors.gd").new()
const NATIVE_UI: Array[String] = ["garage_car_cache.gd","garage_thumbnail_studio.gd","garage_preview_renderer.gd","car_showroom.gd","garage_environment.gd","garage_reflections.gd","garage_details.gd","garage_drain.gd","garage_furnishings.gd","garage_materials.gd","garage_workshop.gd","garage_record_station.gd","garage_plant.gd","garage_car_reveal.gd","garage_wash_effect.gd","garage_wash_geometry.gd","garage_wash_tool.gd","garage_hose_geometry.gd","garage_hose_rig.gd"]

func _sources() -> Dictionary:
	var sources: Dictionary = {}
	for path: String in ["game/ui/garage_mesh_cleanup.gd","game/ui/garage_mesh_reduction.gd","game/rendering/mesh_vertex_packing.gd","game/tests/support/asset_bake_transaction.gd","game/tests/support/asset_bake_errors.gd","scripts/bake_garage_previews.gd"]:
		sources[path] = FileAccess.get_sha256("res://../"+path)
	for directory: String in ["res://vehicle","res://ui"]:
		for name: String in DirAccess.get_files_at(directory):
			if not name.ends_with(".gd") and not name.ends_with(".gdshader") and not name.ends_with(".gdshaderinc"): continue
			if directory.ends_with("/ui") and not (name in NATIVE_UI or name.begins_with("garage_thumbnail_") or name.begins_with("showroom_") or name.begins_with("studio_") or (name.begins_with("garage_") and not name.ends_with(".gd"))): continue
			var path: String = directory.path_join(name)
			sources["game/"+path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	for name: String in DirAccess.get_files_at("res://resources/cars"):
		if name.ends_with(".tres"): sources["game/resources/cars/"+name] = FileAccess.get_sha256("res://resources/cars/"+name)
	for path: String in ["res://vehicle/prepared_asset_dependencies.json","res://resources/original_slide.tres","res://soundtrack/record_library.gd"]:
		sources["game/"+path.trim_prefix("res://")] = FileAccess.get_sha256(path)
	return sources

func _initialize() -> void: run.call_deferred()
func _geometry_revisions() -> Dictionary:
	# Read the revision map from disk again at the fence; loaded GDScript constants
	# cannot observe an identity file rewritten while a bake is rendering.
	var pattern := RegEx.new()
	pattern.compile("MODULAR_CAR_SHA256: Dictionary = (\\{[^\\n]+\\})")
	var found: RegExMatch = pattern.search(FileAccess.get_file_as_string("res://core/build_identity.gd"))
	if found == null: return {}
	var value: Variant = JSON.parse_string(found.get_string(1))
	return value if value is Dictionary else {}

func run() -> void:
	OS.add_logger(bake_errors)
	if DisplayServer.get_name()=="headless":
		push_error("Garage previews require a graphical renderer")
		quit(1)
		return
	var folder: String = "res://assets/garage/previews_v1"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): folder = arg.trim_prefix("--output=")
	folder = ProjectSettings.globalize_path(folder)
	var files: Array[String] = []
	for id: String in VehicleCatalog.IDS: files.append(id+".png")
	files.append("provenance.json")
	var transaction := Transaction.new()
	if transaction.begin(folder, files) != OK:
		push_error("Preview bake is locked or cannot create candidates: " + folder)
		quit(1)
		return
	var provenance_path: String = folder.path_join("provenance.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(provenance_path)) if FileAccess.file_exists(provenance_path) else null
	var previous: Dictionary = parsed if parsed is Dictionary else {}
	var sources: Dictionary = _sources()
	var revision_fence: Dictionary = _geometry_revisions()
	var hashes: Dictionary = {}
	var geometry_revisions: Dictionary = {}
	var prepared_scenes: Dictionary = {}
	var scene_fence: Dictionary = {}
	var publish: Array[String] = []
	for id: String in VehicleCatalog.IDS:
		geometry_revisions[id]=preload("res://vehicle/modular_car_base.gd").build_revision(id)
		var reference:=CarVisual.new()
		reference.vehicle_id=id;reference.simple_model=true
		reference.editable_kits=VehicleCustomisation.supported(id)
		var scene_path: String = preload("res://vehicle/modular_car_base.gd").path_for(reference)
		prepared_scenes[id]=FileAccess.get_sha256(scene_path)
		scene_fence[scene_path] = prepared_scenes[id]
		reference.free()
		if revision_fence.get(id) != geometry_revisions[id]:
			push_error("Loaded preview geometry does not match current build identity")
			transaction.close(); quit(1); return
		if ("--exclude-vehicle="+id) in OS.get_cmdline_user_args():
			# Retain an explicitly protected photograph while updating the shared
			# provenance receipt. Its unchanged model is checked independently.
			if not previous.get("geometry_revisions",{}).has(id) or not previous.get("prepared_scenes",{}).has(id) or transaction.previous[id+".png"] != previous.get("hashes",{}).get(id):
				push_error("Excluded preview needs a matching accepted picture and provenance")
				transaction.close(); quit(1); return
			hashes[id] = transaction.previous[id+".png"]
			geometry_revisions[id] = previous.geometry_revisions[id]
			prepared_scenes[id] = previous.prepared_scenes[id]
			continue
		var view := preload("res://ui/garage_thumbnail_studio.gd").new()
		view.vehicle_id = id
		view.simple_model = true
		view.read_only = true
		view.garage_mode = true
		view.framing_scale = 0.84
		view.livery = VehicleLivery.for_car({},id)
		view.customisation = VehicleCustomisation.defaults()
		view.size = Vector2(2048,512)
		root.add_child(view)
		while not view.showroom_ready: await process_frame
		for index: int in range(5):
			view._submit_render()
			await process_frame
			await RenderingServer.frame_post_draw
		var pixels: Image = view.showroom_viewport.get_texture().get_image()
		var path: String = transaction.candidate(id+".png")
		if pixels.save_png(path)!=OK:
			transaction.close(); quit(1); return
		publish.append(id+".png")
		hashes[id] = FileAccess.get_sha256(path)
		print("NATIVE_THUMBNAIL ",id," ",pixels.get_size()," ",hashes[id])
		view.queue_free()
		await process_frame
		await process_frame
	if bake_errors.failed():
		push_error("Native preview generation logged errors; accepted files preserved")
		transaction.close(); quit(1); return
	if sources != _sources() or revision_fence != _geometry_revisions():
		push_error("Native preview sources changed during the bake; repeat after those edits finish")
		transaction.close()
		quit(1)
		return
	for path: String in scene_fence:
		if scene_fence[path] != FileAccess.get_sha256(path):
			push_error("Prepared scene changed during preview bake")
			transaction.close(); quit(1); return
	var output := FileAccess.open(transaction.candidate("provenance.json"),FileAccess.WRITE)
	if output == null:
		transaction.close(); quit(1); return
	output.store_string(JSON.stringify({"simple":true,"source":"Dedicated thumbnail studio, reduced car, default paint/kits, clean condition, soft seamless backdrop and one car-only planar turntable reflection","engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"size":[2048,512],"hashes":hashes,"geometry_revisions":geometry_revisions,"prepared_scenes":prepared_scenes,"sources":sources},"\t")+"\n")
	output.flush()
	var write_error: Error = output.get_error()
	output.close()
	publish.append("provenance.json")
	var error: Error = transaction.publish(publish) if write_error == OK else write_error
	transaction.close()
	if error != OK: push_error("Preview publication rejected; accepted files preserved: " + error_string(error))
	quit(0 if error == OK else 1)
