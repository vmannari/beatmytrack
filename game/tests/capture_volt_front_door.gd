extends "res://tests/capture_volt_hood_outline.gd"

func run() -> void:
	Engine.time_scale = 0
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/modular_car_kits.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	var output: String = "res://../docs/evidence/volt-front-door-2026-11-17/views-" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1300, 700)
	var count: int = 0
	for mode: String in ["stock", "full"]:
		var room := CarShowroom.new()
		room.vehicle_id = "electric"
		room.simple_model = mode != "full"
		room.garage_mode = true
		room.read_only = true
		room.size = Vector2(1300, 700)
		room.livery = VehicleLivery.defaults("electric")
		room.livery.pattern = "apex_twin"
		room.livery.colors.body = "708ae8"
		room.livery.colors.accent = "7222dd"
		room.livery.colors.detail = "f06484"
		root.add_child(room)
		while not room.showroom_ready or not room.car.model_ready: await process_frame
		room.set_process(false)
		room.yaw = 0
		room.turntable.rotation.y = 0
		var old: Node3D = load("res://../build/volt-front-door-2026-11-17/electric-" + mode + "-before.scn").instantiate()
		room.car.get_parent().add_child(old)
		old.transform = room.car.transform
		room.reflections._mark_stage(old, true)
		for shot: String in ["side", "other-side", "quarter"]:
			room.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			room.camera.size = 2.25 if shot != "quarter" else 2.9
			var target: Vector3 = room.car.position + Vector3(0, 0.66, 0) * HandlingConfig.BODY_SCALE
			var offset: Vector3 = Vector3(6, 0.55, 0)
			if shot == "other-side": offset.x = -6
			if shot == "quarter": offset = Vector3(4, 1.9, -3.8)
			room.camera.position = target + offset * HandlingConfig.BODY_SCALE
			room.camera.look_at(target)
			for suffix: String in ["before", "after"]:
				old.visible = suffix == "before"
				room.car.visible = suffix == "after"
				await settle(room)
				var pixels: Image = room.showroom_viewport.get_texture().get_image()
				assert(pixels.save_png(output.path_join(mode + "-" + shot + "-" + suffix + ".png")) == OK)
				count += 1
		old.free()
		room.free()
		await process_frame
	print("VFD_NATIVE_CAPTURES ", count, " matched images")
	quit()
