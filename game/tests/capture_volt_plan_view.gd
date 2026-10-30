extends SceneTree
## Matched true-overhead native Garage views for the hood outline.
var output: String = "res://../docs/evidence/volt-plan-view-2026-10-30"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(720, 960)
	for striped: bool in [false, true]:
		var room := CarShowroom.new()
		room.vehicle_id = "electric"
		room.read_only = true
		room.garage_mode = true
		room.framing_scale = 0.57
		room.livery = VehicleLivery.defaults("electric")
		if striped:
			var pattern: Dictionary = LiveryCatalog.patterns[LiveryCatalog.pattern_index("endurance")]
			room.livery.pattern = pattern.id
			for slot: int in range(3): room.livery.colors[VehicleLivery.SLOTS[slot]] = pattern.colours[slot]
		room.customisation = VehicleCustomisation.defaults()
		room.size = Vector2(root.size)
		root.add_child(room)
		while not room.showroom_ready: await process_frame
		room.turntable.rotation.y = 0.0
		if is_instance_valid(room.roof): room.roof.hide()
		var target: Vector3 = room.car.global_position + Vector3(0, 0.55, 0)
		room.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		room.camera.size = 5.0
		room.camera.global_position = target + Vector3(0, 6, 0)
		room.camera.look_at(target, Vector3.BACK)
		for frame: int in range(10):
			room.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			room.reflections.request_draw()
			await process_frame
			await RenderingServer.frame_post_draw
		var path: String = output.path_join("striped.png" if striped else "plain.png")
		if room.showroom_viewport.get_texture().get_image().save_png(path) != OK:
			push_error("Failed to save " + path)
			quit(1)
			return
		room.queue_free()
		await process_frame
	print("VOLT_PLAN_VIEW: 2 overhead Garage captures")
	quit()
