extends SceneTree
## Review the combined Mohawk parts in the actual Garage showroom.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var output: String = "res://../build/mohawk-review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var view := CarShowroom.new()
	view.vehicle_id = "kart"
	view.garage_mode = true
	view.livery = VehicleLivery.defaults("kart")
	root.add_child(view)
	MenuStyle.fill(view)
	while not view.showroom_ready: await process_frame
	var parts: Dictionary = VehicleCustomisation.defaults()
	parts.hood = "mohawk"
	parts.body = "mohawk"
	view.apply_customisation(parts)
	view.yaw = 0
	view._orbit()
	for angle: int in range(3):
		var target := Vector3(0,0.34,-0.35)
		var direction: Vector3 = [Vector3(2.2,1.4,-2.8),Vector3(-2.2,1.2,-2.6),Vector3(2.4,1.0,0.5)][angle]
		var at: Vector3 = view.car.body.global_transform*target
		view.camera.look_at_from_position(at+direction,at)
		view.invalidate_render()
		if view.reflections!=null: view.reflections.sync()
		for frame: int in range(15): await process_frame
		await RenderingServer.frame_post_draw
		assert(view.showroom_viewport.get_texture().get_image().save_png(output.path_join("mohawk-%s.png" % angle))==OK)
	print("MOHAWK_REVIEW: 3 views")
	quit()
