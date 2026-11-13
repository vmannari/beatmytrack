extends SceneTree
## RBC01/RBC02: every Rally body kit, both qualities, low and underside views.
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func run() -> void:
	var phase: String = "before"
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase = arg.trim_prefix("--phase=")
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/rally-body-cleanup-2026-11-08/" + phase)
	DirAccess.make_dir_recursive_absolute(output)
	preload("res://vehicle/modular_car_base.gd").enabled = prepared
	preload("res://vehicle/modular_car_kits.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").enabled = prepared
	preload("res://vehicle/prepared_car_cache.gd").entries.clear()
	CompactKits.use_baked = prepared
	root.size = Vector2i(1000, 700)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.0
	camera.current = true
	world.add_child(camera)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.16, 0.19, 0.23)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -35, 0)
	world.add_child(light)
	for simple: bool in [false, true]:
		for option: Array in VehicleCustomisation.OPTIONS.body:
			var kind: String = option[0]
			var hits_before: int = preload("res://vehicle/modular_car_kits.gd").hits
			var car := CarVisual.new()
			car.vehicle_id = "compact"
			car.simple_model = simple
			car.batch_parts = prepared
			car.editable_kits = true
			car.customisation = VehicleCustomisation.defaults()
			car.customisation.body = kind
			world.add_child(car)
			while not car.model_ready: await process_frame
			var label: String = ("simple-" if simple else "standard-") + kind
			if prepared and kind != "stock":
				check(preload("res://vehicle/modular_car_kits.gd").hits>hits_before, label + " restores regenerated module")
			var plate_count: int = 0
			for part: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
				var mesh_key: String = str(CompactKits.meshes.find_key(part.mesh))
				var fin: bool = mesh_key.contains("/strake")
				var fence: bool = mesh_key.contains("/splitterfence")
				var part_name: String = mesh_key
				if not (fin or fence): continue
				plate_count += 1
				var bounds: AABB = part.mesh.get_aabb()
				check(bounds.position.y>0.19, label + " " + part_name + " stays above ground")
				if fin:
					check(bounds.position.z>1.7, label + " " + part_name + " stays at rear diffuser")
				else:
					check(bounds.end.z< -1.6, label + " " + part_name + " stays at nose splitter")
			if not prepared:
				check(plate_count == (7 if kind=="endurance" else 5 if kind=="club" else 3 if kind in ["touring", "urban"] else 0), label + " plate inventory")
			if DisplayServer.get_name() != "headless":
				for pose: Array in [["front", Vector3(-4, 1.1, -5)], ["rear", Vector3(4, 0.8, 5)], ["under", Vector3(3, -3, 4)]]:
					camera.position = pose[1]
					camera.look_at(Vector3(0, 0.45, 0))
					for frame: int in range(3): await process_frame
					await RenderingServer.frame_post_draw
					check(root.get_texture().get_image().save_png(output.path_join(label + "-" + pose[0] + ".png"))==OK, label + " capture")
			car.free()
			await process_frame
	world.free()
	print("RALLY_BODY_UNDERSIDE: ", checks, " checks, ", failures, " failures; prepared=", prepared)
	quit(1 if failures else 0)
