extends SceneTree
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for frame: int in range(10): await process_frame; await RenderingServer.frame_post_draw
func run() -> void:
	root.size = Vector2i(1280,720)
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var view := CarShowroom.new(); view.vehicle_id = "super_rally"; view.garage_mode = true
	view.read_only = true; view.preview_live_lighting = true; view.size = Vector2(1280,720); view.livery = VehicleLivery.defaults("super_rally")
	root.add_child(view)
	while not view.showroom_ready or not view.car.model_ready: await process_frame
	view.finish_car_transition(); view.finish_paint_transition(); view.finish_kit_transition()
	var stage: String = "before"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--stage="): stage = arg.trim_prefix("--stage=")
	var folder: String = "res://../docs/evidence/challenger-quality-2026-11-12/garage-surface-"+stage+"/"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	view.yaw = -0.70; view.elevation = atan(0.32); view.zoom = 1.0; view._orbit(); view.invalidate_render()
	view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS; await settle()
	assert(root.get_texture().get_image().save_png(folder.path_join("shadowed.png")) == OK)
	for part: MeshInstance3D in view.car.find_children("*","MeshInstance3D",true,false): part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.invalidate_render(); await settle()
	assert(root.get_texture().get_image().save_png(folder.path_join("no-car-shadows.png")) == OK)
	view.free();print("GARAGE_SURFACE: raw car, real Garage shadows and unchanged camera control captured");quit()
