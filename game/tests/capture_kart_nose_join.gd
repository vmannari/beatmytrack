extends SceneTree
## Side and front-quarter views of each nose in the actual Garage showroom.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output: String = "res://../build/kart-join-check/views"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	var view := CarShowroom.new()
	view.vehicle_id = "kart"
	view.garage_mode = true
	view.livery = VehicleLivery.defaults("kart")
	root.add_child(view)
	MenuStyle.fill(view)
	while not view.showroom_ready: await process_frame
	for option: Array in VehicleCustomisation.options("hood","kart"):
		var parts: Dictionary = VehicleCustomisation.defaults()
		parts.hood = option[0]
		view.apply_customisation(parts)
		view.yaw = 0
		view._orbit()
		for side: int in [-1, 1]:
			var at: Vector3 = view.car.body.global_transform*Vector3(0,0.31,-1.13)
			view.camera.look_at_from_position(at+Vector3(side*1.8,0.32,-0.8),at)
			view.invalidate_render()
			if view.reflections != null: view.reflections.sync()
			for frame: int in range(8): await process_frame
			await RenderingServer.frame_post_draw
			assert(view.showroom_viewport.get_texture().get_image().save_png(output.path_join(str(option[0])+"_"+str(side)+".png"))==OK)
	view.free()
	print("KART_NOSE_JOIN_VIEWS complete")
	quit()
