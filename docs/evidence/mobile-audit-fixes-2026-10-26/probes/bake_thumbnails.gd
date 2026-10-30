extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder: String = ProjectSettings.globalize_path("res://assets/garage/previews_v1")
	DirAccess.make_dir_recursive_absolute(folder)
	var hashes: Dictionary = {}
	for id: String in VehicleCatalog.IDS:
		var view := CarShowroom.new()
		view.vehicle_id = id
		view.read_only = true
		view.garage_mode = true
		view.framing_scale = 0.84
		view.livery = VehicleLivery.for_car({},id)
		view.customisation = VehicleCustomisation.defaults()
		view.size = Vector2(2048,512)
		root.add_child(view)
		for index: int in range(5):
			view.showroom_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
			view.reflections.request_draw()
			await process_frame
			await RenderingServer.frame_post_draw
		var image: Image = view.showroom_viewport.get_texture().get_image()
		var path: String = folder.path_join(id+".png")
		assert(image.save_png(path)==OK)
		hashes[id] = FileAccess.get_sha256(path)
		print("NATIVE_THUMBNAIL ",id," ",image.get_size()," ",hashes[id])
		view.queue_free()
		await process_frame
		await process_frame
	var output := FileAccess.open(folder.path_join("provenance.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"source":"Original CarShowroom with full native models, original workshop and reflection settings; default paint/kits and clean condition","renderer":RenderingServer.get_current_rendering_method(),"size":[2048,512],"hashes":hashes},"\t"))
	quit()
