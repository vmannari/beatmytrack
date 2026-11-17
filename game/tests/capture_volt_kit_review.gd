extends SceneTree
const OUT = "res://../docs/evidence/volt-kit-review-2026-11-17"

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var phase: String = "before"
	var selected := PackedStringArray()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
		if argument.begins_with("--options="): selected = argument.trim_prefix("--options=").split(",")
	var output: String = OUT.path_join(phase + "-" + RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1100, 700)
	Engine.time_scale = 0
	var count: int = 0
	for simple: bool in [false, true]:
		var room := CarShowroom.new()
		room.vehicle_id = "electric"
		room.simple_model = simple
		room.read_only = true
		room.garage_mode = true
		room.size = Vector2(root.size)
		room.livery = VehicleLivery.defaults("electric")
		room.livery.colors.body = "b8bbb9"
		root.add_child(room)
		while not room.showroom_ready or not room.car.model_ready: await process_frame
		room.set_process(false)
		room.turntable.rotation.y = 0
		room.yaw = 0
		for category: String in VehicleCustomisation.CATEGORIES:
			for option: Array in VehicleCustomisation.options(category, "electric"):
				if not selected.is_empty() and str(option[0]) not in selected: continue
				var parts: Dictionary = VehicleCustomisation.defaults()
				parts[category] = option[0]
				var hits: int = preload("res://vehicle/modular_car_kits.gd").hits
				room.apply_customisation(parts)
				assert(room.car.customisation[category] == option[0])
				if phase == "after" and option[0] != "stock":
					assert(preload("res://vehicle/modular_car_kits.gd").hits > hits,"Every photographed part uses the rebuilt prepared module")
				var shots: Array[String] = ["detail", "whole"]
				if phase in ["after","rear-candidate"] and category != "aero": shots.append("extra")
				for shot: String in shots:
					var target := Vector3(0, 0.72, -1.55)
					var offset := Vector3(1.7, 2.6, -2.4)
					var extent: float = 1.9
					if category == "body":
						target = Vector3(0, 0.32, -0.15)
						offset = Vector3(4, 0.9, -3.8)
						extent = 3.15
					if category == "aero":
						target = Vector3(0, 0.91, 1.90)
						offset = Vector3(1.8, 1.3, 2.4)
						extent = 1.8
					if category == "rims":
						target = Vector3(0.86, 0.37, -1.398)
						offset = Vector3(3, 0.25, -0.45)
						extent = 0.98
					if shot == "whole":
						target = Vector3(0, 0.65, 0)
						offset = Vector3(4, 2.1, 4 if category == "aero" else -4)
						extent = 3.7
					if shot == "extra":
						if category == "hood": offset = Vector3(0,0.65,-4)
						if category == "body":
							target = Vector3(0,0.35,1.55)
							offset = Vector3(3,1,3.8)
							extent = 2.3
						if category == "rims":
							target.x = -target.x
							offset.x = -offset.x
					room.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
					room.camera.size = extent
					room.camera.position = room.car.position + (target + offset) * HandlingConfig.BODY_SCALE
					room.camera.look_at(room.car.position + target * HandlingConfig.BODY_SCALE)
					room.invalidate_render()
					for frame: int in range(8):
						await process_frame
						await RenderingServer.frame_post_draw
					var picture: Image = room.showroom_viewport.get_texture().get_image()
					var file: String = category + "-" + str(option[0]) + ("-simple-" if simple else "-full-") + shot + ".png"
					assert(picture.save_png(output.path_join(file)) == OK)
					count += 1
		room.free()
		await process_frame
	print("VKR_NATIVE_CAPTURES ", count, " images")
	quit()
