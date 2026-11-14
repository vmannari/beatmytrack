extends SceneTree
## Identical studio/native Garage material comparison, without player state.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var phase: String = "before"
	var vehicle: String = ""
	var body_color: String = ""
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
		if argument.begins_with("--vehicle="): vehicle = argument.trim_prefix("--vehicle=")
		if argument.begins_with("--body-color="): body_color = argument.trim_prefix("--body-color=")
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/modular_car_kits.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = false
	var directory: String = "res://../docs/evidence/visual-fixes-2026-11-13/materials/" + phase + "/" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for id: String in ["compact", "electric", "super_rally", "forklift", "hovercraft", "kart"]:
		if not vehicle.is_empty() and id != vehicle: continue
		var view := CarShowroom.new()
		view.vehicle_id = id
		view.simple_model = true
		view.read_only = true
		view.livery = VehicleLivery.defaults(id)
		if not body_color.is_empty(): view.livery.colors.body = body_color
		view.customisation = VehicleCustomisation.defaults()
		view.size = Vector2(1000, 760)
		root.add_child(view)
		var deadline: int = Time.get_ticks_msec() + 90000
		while (not view.showroom_ready or not view.car.model_ready) and Time.get_ticks_msec() < deadline:
			await process_frame
		assert(view.showroom_ready and view.car.model_ready, "vehicle ready " + id)
		view.finish_car_transition()
		view.finish_paint_transition()
		view.finish_kit_transition()
		for shot: Array in [["front", -0.70, 0.31], ["side", -PI/2, 0.15]]:
			view.yaw = shot[1]
			view.elevation = shot[2]
			view.zoom = 1.05 if id in ["compact", "forklift", "super_rally"] else 0.85
			view._orbit()
			view.invalidate_render()
			for frame: int in range(12):
				await process_frame
				await RenderingServer.frame_post_draw
			assert(view.showroom_viewport.get_texture().get_image().save_png(directory.path_join(id+"-"+shot[0]+".png")) == OK)
		view.free()
		await process_frame
		print("VEHICLE_FINISH_CAPTURE ", phase, " ", id)
	quit()
