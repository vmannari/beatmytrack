extends SceneTree
var output: String = "res://../build/hovercraft-kit-review"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var category_filter: String = ""
	var captures: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--category="): category_filter = arg.trim_prefix("--category=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	var view := CarShowroom.new()
	view.vehicle_id = "hovercraft"
	view.garage_mode = true
	view.livery = VehicleLivery.defaults("hovercraft")
	root.add_child(view)
	MenuStyle.fill(view)
	while not view.showroom_ready: await process_frame
	for category: String in VehicleCustomisation.CATEGORIES:
		if not category_filter.is_empty() and category != category_filter: continue
		for option: Array in VehicleCustomisation.options(category,"hovercraft"):
			var parts: Dictionary = VehicleCustomisation.defaults()
			parts[category] = option[0]
			view.apply_customisation(parts)
			view.yaw = 0
			view._orbit()
			var target: Vector3
			var direction: Vector3
			match category:
				"hood": target = Vector3(0,0.76,-1.45); direction = Vector3(1.5,1.6,-2.5)
				"aero": target = Vector3(0,1.25,1.65); direction = Vector3(2,1.2,2.8)
				"rims": target = Vector3(0,1.03,1.25); direction = Vector3(0.4,0.7,-2.5)
				"body": target = Vector3(0.7,0.65,0); direction = Vector3(2.8,1,-1.5)
			var at: Vector3 = view.car.body.global_transform*target
			view.camera.look_at_from_position(at+direction,at)
			view.invalidate_render()
			if view.reflections != null: view.reflections.sync()
			for i: int in range(4): await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = view.showroom_viewport.get_texture().get_image()
			assert(image.save_png(output.path_join(category+"-"+str(option[0])+".png")) == OK)
			captures += 1
	print("HOVERCRAFT_KIT_REVIEW: captured %d views" % captures)
	view.free()
	quit()
