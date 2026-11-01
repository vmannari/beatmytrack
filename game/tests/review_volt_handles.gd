extends SceneTree
## Close review of both actual door sides, without prepared-mesh caches.
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := "res://../tmp/volt-handles-after"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		if argument.begins_with("--baseline-source="):
			var source: String = FileAccess.get_file_as_string(argument.trim_prefix("--baseline-source="))
			assert(not source.is_empty())
			var details: GDScript = load("res://vehicle/electric_reference_details.gd")
			details.source_code = source
			assert(details.reload() == OK)
	var mesh_builder = preload("res://vehicle/electric_reference_mesh.gd")
	mesh_builder.use_baked = false
	mesh_builder.meshes.clear()
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1440, 720)
	var room := CarShowroom.new()
	room.vehicle_id = "electric"
	room.read_only = true
	room.garage_mode = true
	room.framing_scale = 0.57
	room.zoom = 0.9
	room.livery = VehicleLivery.defaults("electric")
	room.customisation = VehicleCustomisation.defaults()
	room.size = Vector2(root.size)
	root.add_child(room)
	while not room.showroom_ready: await process_frame
	for shot: Array in [["left", -PI * 0.5], ["right", PI * 0.5]]:
		room.elevation = atan(0.08)
		room._orbit()
		room.turntable.rotation.y = float(shot[1]) - CarShowroom.GARAGE_CAMERA_YAW
		room.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		room.camera.size = 1.4
		for frame: int in range(6):
			room.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			room.reflections.request_draw()
			await process_frame
			await RenderingServer.frame_post_draw
		var path: String = output.path_join(str(shot[0]) + ".png")
		assert(room.showroom_viewport.get_texture().get_image().save_png(path) == OK)
	room.queue_free()
	await process_frame
	print("VOLT_HANDLE_REVIEW: captured both door sides to ", output)
	quit()
