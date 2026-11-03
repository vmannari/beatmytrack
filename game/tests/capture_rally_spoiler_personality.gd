extends SceneTree
## Compare each Rally spoiler independently in the actual Garage showroom.
var output: String = "res://../build/rally-spoiler-personality/captures"
var showroom: CarShowroom
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func capture(label: String) -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var error: Error = showroom.showroom_viewport.get_texture().get_image().save_png(output.path_join(label + ".png"))
	if error != OK:
		failures += 1
		push_error("Capture failed: " + label)

func run() -> void:
	var source: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--evidence-root="): output = arg.trim_prefix("--evidence-root=")
		if arg == "--source": source = true
	if source:
		CompactKits.use_baked = false
		preload("res://vehicle/modular_car_kits.gd").enabled = false
		preload("res://vehicle/modular_car_base.gd").enabled = false
		preload("res://vehicle/prepared_car_cache.gd").enabled = false
		preload("res://ui/garage_car_cache.gd").enabled = false
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 900)
	var host := Control.new()
	root.add_child(host)
	MenuStyle.fill(host)
	showroom = CarShowroom.new()
	showroom.garage_mode = true
	showroom.livery = VehicleLivery.defaults("compact")
	host.add_child(showroom)
	MenuStyle.fill(showroom)
	for frame: int in range(12): await process_frame
	for option: Array in VehicleCustomisation.OPTIONS.aero:
		var profile: Dictionary = VehicleCustomisation.defaults()
		profile.aero = option[0]
		showroom.apply_customisation(profile)
		showroom.zoom = 0.49
		showroom.elevation = 0.22
		showroom.yaw = PI - 0.63
		showroom._orbit()
		await capture(str(option[0]) + "-rear")
		showroom.yaw = PI / 2.0
		showroom._orbit()
		await capture(str(option[0]) + "-side")
		var target: Vector3 = showroom.car.body.global_transform * Vector3(0.0, 1.38, 1.64)
		showroom.camera.look_at_from_position(target + Vector3(1.9, 0.85, 2.1), target)
		showroom.reflections.sync()
		await capture(str(option[0]) + "-detail")
	print("RALLY_SPOILER_CAPTURE: ", VehicleCustomisation.OPTIONS.aero.size() * 3, " views; failures=", failures, " source=", source)
	host.queue_free()
	await process_frame
	quit(1 if failures else 0)
