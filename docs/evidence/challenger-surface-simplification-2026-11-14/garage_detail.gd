extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	for tier: String in ["simple", "full"]:
		var prefix: String = "res://../build/challenger-surface-simplification-2026-11-14/native/"
		if "--candidate" in OS.get_cmdline_user_args():
			SuperRallyModel.assets[SuperRallyModel.ROOT+tier+"_body_paint.res"] = load(prefix+tier+"_body_paint.res")
			SuperRallyModel.assets[SuperRallyModel.ROOT+tier+"_body_contour.res"] = load(prefix+tier+"_body_contour.res")
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/modular_car_kits.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = prepared
	if "--before" in OS.get_cmdline_user_args():
		var baseline: String = "res://../docs/evidence/challenger-surface-simplification-2026-11-14/before/"
		var manifest: Dictionary = (load(SuperRallyModel.ROOT+"manifest.json") as JSON).data
		for tier: String in ["simple","full"]:
			for item: Dictionary in manifest.tiers[tier]:
				var path: String = baseline+str(item.mesh)
				assert(FileAccess.file_exists(path),path)
				SuperRallyModel.assets[SuperRallyModel.ROOT+str(item.mesh)] = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE)
	if "--candidate" in OS.get_cmdline_user_args():
		var candidate: String="res://../build/challenger-surface-simplification-2026-11-14/native/"
		var manifest: Dictionary=(load(candidate+"manifest.json") as JSON).data
		for tier: String in ["simple","full"]:
			for item: Dictionary in manifest.tiers[tier]:
				SuperRallyModel.assets[SuperRallyModel.ROOT+str(item.mesh)]=ResourceLoader.load(candidate+str(item.mesh),"",ResourceLoader.CACHE_MODE_IGNORE)
	var stage: String = "before"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
	var view := CarShowroom.new()
	view.vehicle_id = "super_rally"; view.simple_model = true; view.garage_mode = true
	view.livery = VehicleLivery.defaults("super_rally"); view.size = Vector2(1440,900)
	root.add_child(view)
	while not view.showroom_ready or not view.car.model_ready: await process_frame
	view.finish_car_transition(); view.finish_paint_transition(); view.finish_kit_transition()
	view.set_process(false)
	if "--no-car-shadows" in OS.get_cmdline_user_args():
		for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if "--normals" in OS.get_cmdline_user_args():
		var shader := Shader.new(); shader.code = "shader_type spatial; render_mode unshaded; void fragment(){ALBEDO = NORMAL*0.5+0.5;}"
		var material := ShaderMaterial.new();material.shader = shader
		for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false):part.material_override = material
	var folder: String = "res://../docs/evidence/challenger-surface-simplification-2026-11-14/garage-"+stage+"/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for paint: String in ["red","white"]:
		if paint == "white":
			var custom: Dictionary = VehicleLivery.defaults("super_rally")
			custom.colors.body = "ffffff"; custom.colors.accent = "9d2424"
			view.livery = custom; view.car.apply_livery(custom)
		for angle: Array in [["reference",-0.82,0.17],["front",0.0,0.11],["opposite",0.82,0.17],["side",-PI/2,0.12]]:
			view.yaw = angle[1]; view.elevation = angle[2]; view.zoom = 0.64; view._orbit()
			view.camera.position.y -= 0.35; view.camera.look_at(Vector3(0,0.87,0))
			view.reflections.sync(); view.reflections.request_draw(); view.invalidate_render()
			view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			for frame: int in range(16): await process_frame; await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(folder.path_join(paint+"-"+angle[0]+".png")) == OK)
	view.free()
	print("CHALLENGER_GARAGE_DETAIL: eight actual native workshop views saved")
	quit()
