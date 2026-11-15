extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	var stage: String = "before"
	var candidate: bool = "--candidate" in OS.get_cmdline_user_args()
	var simple: bool = "--full" not in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/modular_car_kits.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = prepared
	if candidate:
		var prefix: String = "res://../build/challenger-panel-corrections-2026-11-14/native/"
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix+"manifest.json"))
		(load(SuperRallyModel.ROOT+"manifest.json") as JSON).data = manifest
		SuperRallyModel.hood_profile = JSON.parse_string(FileAccess.get_file_as_string(prefix+"hood_profile.json"))
		(load(SuperRallyModel.ROOT+"bonnet_contour.json") as JSON).data = JSON.parse_string(FileAccess.get_file_as_string(prefix+"bonnet_contour.json"))
		for tier: String in ["simple","full"]:
			for entry: Dictionary in manifest.tiers[tier]:
				var mesh: ArrayMesh = load(prefix+str(entry.mesh))
				mesh.take_over_path(SuperRallyModel.ROOT+str(entry.mesh))
				SuperRallyModel.assets[SuperRallyModel.ROOT+str(entry.mesh)] = mesh
	var view := CarShowroom.new()
	view.vehicle_id = "super_rally"; view.simple_model = simple; view.garage_mode = true
	view.livery = VehicleLivery.defaults("super_rally"); view.size = Vector2(1440,900)
	root.add_child(view)
	while not view.showroom_ready or not view.car.model_ready: await process_frame
	if "--hide-contour" in OS.get_cmdline_user_args():
		for part: MeshInstance3D in view.car.find_children("*contour*","MeshInstance3D",true,false): part.visible = false
	view.finish_car_transition(); view.finish_paint_transition(); view.finish_kit_transition(); view.set_process(false)
	view.yaw = 0; view.turntable.rotation.y = 0
	var folder: String = "res://../build/challenger-panel-corrections-2026-11-14/views-"+stage+"/"+RenderingServer.get_current_rendering_method()+"/"+("simple" if simple else "full")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var captures: int = 0
	for paint: String in ["white","red"]:
		if "--white-only" in OS.get_cmdline_user_args() and paint == "red": continue
		var livery: Dictionary = VehicleLivery.defaults("super_rally")
		livery.colors.body = "ffffff" if paint == "white" else "c52a20"
		livery.colors.accent = "9d2424"; view.livery = livery; view.car.apply_livery(livery)
		for shot: Array in [["rear",Vector3(0,1.25,6.4),Vector3(0,.72,1.0),Vector3.UP],
			["front",Vector3(0,1.20,-6.4),Vector3(0,.72,-1.0),Vector3.UP],
			["left",Vector3(-6.3,1.25,0),Vector3(0,.75,0),Vector3.UP],
			["right",Vector3(6.3,1.25,0),Vector3(0,.75,0),Vector3.UP],
			["overhead",Vector3(0,6.3,-.4),Vector3(0,.7,-.4),Vector3.RIGHT],
			["front-quarter",Vector3(-4.5,2.0,-5.0),Vector3(0,.8,-.3),Vector3.UP],
			["rear-quarter",Vector3(-4.4,1.7,4.8),Vector3(0,.8,.5),Vector3.UP],
			["door-corner",Vector3(-3.8,.9,.65),Vector3(-.6,.48,.65),Vector3.UP]]:
			view.turntable.rotation.y = 0
			var pose: Transform3D = view.car.global_transform
			view.camera.global_position = pose*shot[1]; view.camera.look_at(pose*shot[2],pose.basis*shot[3])
			view._update_roof()
			view.reflections.sync(); view.reflections.request_draw(); view.invalidate_render()
			view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			for frame: int in range(24): await process_frame; await RenderingServer.frame_post_draw
			captures += 1
			assert(root.get_texture().get_image().save_png(folder.path_join(paint+"-"+shot[0]+".png")) == OK)
	view.free()
	print("PANEL_VIEWS: ",captures," actual model views saved; ",stage," simple=",simple)
	quit()
