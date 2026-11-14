extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1440,900)
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	var folder: String="res://../docs/evidence/challenger-corner-finalise-2026-11-13/closeup/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for stage: String in ["before","final"]:
		var base: String=folder.get_base_dir().get_base_dir().path_join("before/") if stage=="before" else SuperRallyModel.ROOT
		if stage=="before":base="res://../docs/evidence/challenger-corner-finalise-2026-11-13/before/"
		var manifest: Dictionary=(load(SuperRallyModel.ROOT+"manifest.json") as JSON).data
		for tier: String in ["simple","full"]:
			for item: Dictionary in manifest.tiers[tier]:
				SuperRallyModel.assets[SuperRallyModel.ROOT+str(item.mesh)]=ResourceLoader.load(base+str(item.mesh),"",ResourceLoader.CACHE_MODE_IGNORE)
		var view:=CarShowroom.new();view.vehicle_id="super_rally";view.simple_model=true;view.garage_mode=true
		view.size=Vector2(root.size);view.livery=VehicleLivery.defaults("super_rally");root.add_child(view)
		while not view.showroom_ready or not view.car.model_ready:await process_frame
		view.finish_car_transition();view.finish_paint_transition();view.finish_kit_transition();view.set_process(false)
		view.yaw=.82;view.elevation=.16;view._orbit()
		var target: Vector3=view.car.to_global(Vector3(.73,.79,-2.08))
		view.camera.global_position=target+view.car.global_transform.basis*Vector3(.67,.31,-1.38)
		view.camera.look_at(target);view.camera.near=.03
		view.reflections.sync();view.reflections.request_draw();view.invalidate_render()
		view.showroom_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		for frame: int in range(32):await process_frame;await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder.path_join(stage+".png"))==OK)
		view.free();await process_frame
	print("CORNER_CLOSEUP: matched native before/final views");quit()
