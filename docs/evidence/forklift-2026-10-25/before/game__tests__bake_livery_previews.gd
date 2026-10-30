extends SceneTree
## Offline native renders of existing models; no preview viewport runs in the menu.
func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,200)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var total: int = 0
	var plain_count: int = GaragePage.LIVERY_NAMES.size()
	var recipe_count: int = plain_count+LiveryCatalog.patterns.size()
	var only: PackedStringArray = []
	var only_vehicle: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--patterns="): only = argument.trim_prefix("--patterns=").split(",",false)
		if argument.begins_with("--vehicle="): only_vehicle = argument.trim_prefix("--vehicle=")
	assert(only_vehicle.is_empty() or only_vehicle in VehicleCatalog.IDS)
	for id: String in VehicleCatalog.IDS:
		if not only_vehicle.is_empty() and id!=only_vehicle: continue
		var captured: int = 0
		var world := Node3D.new()
		viewport.add_child(world)
		var car := CarVisual.new()
		car.vehicle_id = id
		car.livery = VehicleLivery.defaults(id)
		world.add_child(car)
		ShowroomStudio.build(world,car)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.current = true
		camera.fov = 32.0
		var factor: float = (1.14 if id == "pickup" else 0.71 if id == "kart" else 0.95)*0.56
		var target := Vector3(0,0.6,0)
		camera.position = target+Vector3(-5,5,-8)*factor
		camera.look_at(target)
		var directory: String = "res://assets/liveries/previews_v2/"+id
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
		for index: int in range(recipe_count):
			var value: Dictionary = VehicleLivery.defaults(id)
			var key: String = GaragePage.LIVERY_NAMES[index].to_lower() if index < plain_count else LiveryCatalog.patterns[index-plain_count].id
			if not only.is_empty() and key not in only: continue
			if index < plain_count:
				value.colors.body = GaragePage.LIVERY_COLORS[index][0]
				value.colors.accent = GaragePage.LIVERY_COLORS[index][1]
			else:
				var pattern: Dictionary = LiveryCatalog.patterns[index-plain_count]
				key = pattern.id
				value.pattern = key
				for slot: int in range(3): value.colors[VehicleLivery.SLOTS[slot]] = pattern.colours[slot]
			car.apply_livery(value)
			for frame: int in range(3): await process_frame
			await RenderingServer.frame_post_draw
			var pixels: Image = viewport.get_texture().get_image()
			pixels.convert(Image.FORMAT_RGB8)
			var error: Error = pixels.save_png(directory.path_join(key+".png"))
			if error != OK:
				push_error("Livery preview save failed: "+id+"/"+key)
				quit(1)
				return
			total += 1
			captured += 1
		world.queue_free()
		await process_frame
		print("LIVERY_PREVIEWS: "+id+" "+str(captured)+" actual model captures")
	viewport.queue_free()
	await process_frame
	print("LIVERY_PREVIEWS: "+str(total)+" captures complete")
	quit()
