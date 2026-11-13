extends SceneTree
## Run with the pinned engine and a graphical renderer. Native game assets only.
const NATIVE_UI: Array[String] = ["garage_car_cache.gd","garage_thumbnail_studio.gd","garage_preview_renderer.gd","car_showroom.gd","garage_environment.gd","garage_reflections.gd","garage_details.gd","garage_drain.gd","garage_furnishings.gd","garage_materials.gd","garage_workshop.gd","garage_record_station.gd","garage_lp_box.gd","garage_plant.gd","garage_car_reveal.gd","garage_wash_effect.gd","garage_wash_geometry.gd","garage_wash_tool.gd","garage_hose_geometry.gd","garage_hose_rig.gd"]

func _sources() -> Dictionary:
	var sources: Dictionary = {}
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
func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Garage previews require a graphical renderer")
		quit(1)
		return
	var folder: String = ProjectSettings.globalize_path("res://assets/garage/previews_v1")
	DirAccess.make_dir_recursive_absolute(folder)
	var sources: Dictionary = _sources()
	var hashes: Dictionary = {}
	var geometry_revisions: Dictionary = {}
	var prepared_scenes: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		geometry_revisions[id]=preload("res://vehicle/modular_car_base.gd").build_revision(id)
		prepared_scenes[id]=FileAccess.get_sha256("res://assets/garage/cars_v1/"+id+".scn")
		var view := preload("res://ui/garage_thumbnail_studio.gd").new()
		view.vehicle_id = id
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
		var path: String = folder.path_join(id+".png")
		if pixels.save_png(path)!=OK: quit(1); return
		hashes[id] = FileAccess.get_sha256(path)
		print("NATIVE_THUMBNAIL ",id," ",pixels.get_size()," ",hashes[id])
		view.queue_free()
		await process_frame
		await process_frame
	if sources != _sources():
		push_error("Native preview sources changed during the bake; repeat after those edits finish")
		quit(1)
		return
	var output := FileAccess.open(folder.path_join("provenance.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"source":"Dedicated thumbnail studio, full car, default paint/kits, clean condition, soft seamless backdrop and one car-only planar turntable reflection","engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"size":[2048,512],"hashes":hashes,"geometry_revisions":geometry_revisions,"prepared_scenes":prepared_scenes,"sources":sources},"\t")+"\n")
	quit()
