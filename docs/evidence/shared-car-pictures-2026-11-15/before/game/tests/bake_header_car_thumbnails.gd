extends SceneTree
## Offline asset build only. No studio is instantiated by the header at runtime.
const Profile = preload("res://ui/profile_car.gd")
const SIZE := Vector2i(176,112)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	var destination: String = "res://assets/menu/header_cars_v1"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.disable_3d = true
	canvas.transparent_bg = true
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var rows: Array[Dictionary] = []
	for id: String in VehicleCatalog.IDS:
		if id=="super_rally" and "--exclude-vehicle=super_rally" in OS.get_cmdline_user_args(): continue
		var view: Control = Profile.make_preview(id,VehicleLivery.defaults(id),VehicleCustomisation.defaults())
		view.size = Vector2(SIZE)
		canvas.add_child(view)
		Profile.apply_presentation(view)
		while view.car==null or not view.car.model_ready: await process_frame
		for _frame: int in range(7):
			await process_frame
			await RenderingServer.frame_post_draw
		var pixels: Image = canvas.get_texture().get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		# Canvas output is premultiplied; PNGs use straight alpha for normal 2D UI.
		for y: int in range(SIZE.y):
			for x: int in range(SIZE.x):
				var color: Color = pixels.get_pixel(x,y)
				if color.a > 0.0 and color.a < 1.0:
					pixels.set_pixel(x,y,Color(minf(1,color.r/color.a),minf(1,color.g/color.a),minf(1,color.b/color.a),color.a))
		var path: String = destination.path_join(id+".png")
		assert(pixels.save_png(path) == OK)
		rows.append({"vehicle":id,"path":path,"sha256":FileAccess.get_sha256(path),"bytes":FileAccess.get_file_as_bytes(path).size(),"visible_bounds":str(pixels.get_used_rect())})
		view.queue_free()
		await process_frame
	var receipt: String="res://../docs/evidence/header-car-lightweight-2026-10-26/bake.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): receipt=argument.trim_prefix("--evidence-root=").path_join("header-defaults.json")
	var evidence := FileAccess.open(receipt,FileAccess.WRITE)
	evidence.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"size":str(SIZE),"appearance":"standard car; original profile studio","assets":rows},"\t"))
	evidence.close()
	canvas.queue_free()
	await process_frame
	print("HEADER_THUMBNAIL_BAKE: ",rows.size()," pictures")
	quit()
