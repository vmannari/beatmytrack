extends SceneTree
const OUT = "res://../docs/evidence/car-loading-improvements-2026-11-13"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var phase: String = "after"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/modular_car_kits.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://ui/garage_car_cache.gd").enabled = false
	var directory: String = OUT.path_join(phase).path_join(RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		if ("--exclude-vehicle="+id) in OS.get_cmdline_user_args(): continue
		var view := CarShowroom.new()
		view.vehicle_id = id
		view.simple_model = true
		view.read_only = true
		view.livery = VehicleLivery.defaults(id)
		view.customisation = VehicleCustomisation.defaults()
		view.size = Vector2(1000,760)
		var prior_hits: int = preload("res://vehicle/modular_car_base.gd").hits
		root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready: await process_frame
		if prepared: assert(preload("res://vehicle/modular_car_base.gd").hits==prior_hits+1,"Capture must use current prepared base")
		for shot: Array in [["front",-0.70,0.31],["rear",2.45,0.31],["side",-PI/2,0.15],["overhead",-0.4,1.02]]:
			view.yaw = shot[1]
			view.elevation = shot[2]
			view.zoom = 1.05 if id in ["compact","forklift","super_rally"] else 0.85
			view._orbit()
			view.invalidate_render()
			for frame: int in range(16):
				await process_frame
				await RenderingServer.frame_post_draw
			assert(view.showroom_viewport.get_texture().get_image().save_png(directory.path_join(id+"-"+shot[0]+".png"))==OK)
		view.free()
		await process_frame
		print("MODEL_REFINEMENT_CAPTURE ",phase," ",id)
	quit()
