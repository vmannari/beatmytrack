extends SceneTree
## Settled native operator-support views using the production Garage world.
var output: String = ""

func _initialize() -> void: run.call_deferred()

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if not prepared:
		preload("res://vehicle/modular_car_base.gd").enabled = false
		preload("res://vehicle/prepared_car_cache.gd").enabled = false
		preload("res://ui/garage_car_cache.gd").enabled = false
	root.size = Vector2i(1280,960)
	root.content_scale_size = root.size
	var showroom := CarShowroom.new()
	showroom.vehicle_id = "forklift"
	showroom.garage_mode = true
	showroom.livery = VehicleLivery.defaults("forklift")
	root.add_child(showroom)
	MenuStyle.fill(showroom)
	while not showroom.showroom_ready: await process_frame
	var poses: Dictionary = {
		"controls": [Vector3(2.8,1.85,-1.6),Vector3(0.22,1.12,-0.12)],
		"seat": [Vector3(-2.8,1.55,-0.2),Vector3(0,1.12,0.12)]
	}
	for label: String in poses:
		var pose: Array = poses[label]
		var transform: Transform3D = showroom.car.body.global_transform
		showroom.camera.look_at_from_position(transform*pose[0],transform*pose[1])
		showroom.invalidate_render()
		if showroom.reflections != null: showroom.reflections.sync()
		for tick: int in range(8): await process_frame
		await RenderingServer.frame_post_draw
		assert(showroom.showroom_viewport.get_texture().get_image().save_png(output.path_join(label+".png")) == OK)
	showroom.free()
	print("FORKLIFT_OPERATOR_CAPTURE: 2 native views; prepared=",prepared)
	quit()
