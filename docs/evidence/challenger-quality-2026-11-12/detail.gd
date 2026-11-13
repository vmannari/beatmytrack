extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1440,900)
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var view := CarShowroom.new()
	view.vehicle_id = "super_rally"; view.simple_model = true; view.read_only = true
	view.livery = VehicleLivery.defaults("super_rally"); view.size = Vector2(1440,900)
	root.add_child(view)
	while not view.showroom_ready or not view.car.model_ready: await process_frame
	view.finish_car_transition(); view.finish_paint_transition(); view.finish_kit_transition()
	var folder: String = "res://../docs/evidence/challenger-quality-2026-11-12/detail"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): folder += "-"+arg.trim_prefix("--stage=")
	folder = folder.path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for angle: Array in [["front",-0.70,0.32],["rear",2.45,0.32],["side",-PI/2,0.15],["right",PI/2,0.15],["overhead",-0.40,1.02]]:
		view.yaw = angle[1]; view.elevation = angle[2]; view.zoom = 0.75; view._orbit(); view.invalidate_render()
		view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		for frame: int in range(8): await process_frame; await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder.path_join(angle[0]+".png")) == OK)
	view.free()
	print("CHALLENGER_DETAIL: five actual native views saved")
	quit()
