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
	for id: String in VehicleCatalog.IDS:
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
		for index: int in range(24):
			var value: Dictionary = VehicleLivery.defaults(id)
			var key: String = "original" if index == 0 else "rally" if index == 1 else "midnight" if index == 2 else "sandstone"
			if index > 0 and index < 4:
				value.colors.body = GaragePage.LIVERY_COLORS[index][0]
				value.colors.accent = GaragePage.LIVERY_COLORS[index][1]
			elif index >= 4:
				var pattern: Dictionary = LiveryCatalog.patterns[index-4]
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
		world.queue_free()
		await process_frame
		print("LIVERY_PREVIEWS: "+id+" 24 actual model captures")
	viewport.queue_free()
	await process_frame
	print("LIVERY_PREVIEWS: 120 captures complete")
	quit()
