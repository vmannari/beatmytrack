extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var phase: String = "before"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var directory: String = "res://../docs/evidence/kart-clothing-2026-11-14/"+phase+"/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var view := CarShowroom.new()
	view.vehicle_id = "kart"
	view.simple_model = true
	view.read_only = true
	view.livery = VehicleLivery.defaults("kart")
	view.customisation = VehicleCustomisation.defaults()
	view.size = Vector2(1280,960)
	root.add_child(view)
	while not view.showroom_ready or not view.car.model_ready: await process_frame
	for shot: Array in [["front",-0.70,0.31],["side",-PI/2,0.30],["overhead",-0.4,1.02]]:
		view.yaw = shot[1]
		view.elevation = shot[2]
		view.zoom = 0.72
		view._orbit()
		view.invalidate_render()
		for frame: int in range(16):
			await process_frame
			await RenderingServer.frame_post_draw
		assert(view.showroom_viewport.get_texture().get_image().save_png(directory.path_join(shot[0]+".png")) == OK)
	view.free()
	await process_frame
	print("KART_MATERIAL_CAPTURE ",phase," complete")
	quit()
