extends SceneTree
## RW01/RW02: inspect the actual Rally glass in both mesh qualities.
var output: String = "res://../docs/evidence/rally-windows-2026-11-08"
var phase: String = "before"
var prepared: bool = false
var validate: bool = false
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--phase="): phase = argument.trim_prefix("--phase=")
		if argument == "--prepared": prepared = true
		if argument == "--validate": validate = true
	output = ProjectSettings.globalize_path(output).path_join(phase)
	DirAccess.make_dir_recursive_absolute(output)
	preload("res://vehicle/modular_car_base.gd").enabled = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	preload("res://ui/garage_car_cache.gd").enabled = false
	preload("res://vehicle/compact_glazing.gd").use_baked = prepared
	root.size = Vector2i(1280, 720)
	root.msaa_3d = Viewport.MSAA_4X
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4.8
	camera.current = true
	world.add_child(camera)
	var studio_built: bool = false
	for simple: bool in [false, true]:
		var car := CarVisual.new()
		car.vehicle_id = "compact"
		car.simple_model = simple
		car.batch_parts = false
		world.add_child(car)
		while not car.model_ready: await process_frame
		if not studio_built:
			ShowroomStudio.build(world, car)
			studio_built = true
		else: ShowroomStudio._studio_glass(car, {})
		for suffix: String in ["Left", "Right"]:
			var door: MeshInstance3D = car.body.get_node("DoorWindow" + suffix + "Glass")
			var quarter: MeshInstance3D = car.body.get_node("QuarterWindow" + suffix + "Glass")
			var a: AABB = door.mesh.get_aabb()
			var b: AABB = quarter.mesh.get_aabb()
			check(absf(a.position.y-b.position.y)<0.001, "aligned lower glass edges " + suffix)
			check(absf(a.end.y-b.end.y)<0.001, "aligned upper glass edges " + suffix)
			check(b.position.z-a.end.z>0.055, "separate pillar " + suffix)
			if validate:
				check(a.position.y<1.055 and a.position.y>1.025, "glass reaches the lower cabin without crossing the belt " + suffix)
				for window: MeshInstance3D in [door, quarter]:
					var clearance: float = INF
					for point: Vector3 in window.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
						clearance = minf(clearance, absf(point.x)-CompactCoachwork.cabin_width((point.y-1.01)/0.47))
					check(clearance>0.004, "side glass stays outside the body " + window.name)
			print("WINDOW_BOUNDS simple=", simple, " ", suffix, " ", a, " quarter=", b)
		for name: String in ["FrontGlassSheet", "RearGlassSheet"]:
			var sheet: MeshInstance3D = car.body.get_node(name)
			var arrays: Array = sheet.mesh.surface_get_arrays(0)
			var valid: bool = true
			for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
				valid = valid and n.is_finite() and n.length_squared()>0.9
			check(valid, "finite glass normals " + name)
			if validate and name == "FrontGlassSheet":
				var clearance: float = INF
				for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					var height: float = (point.y-1.01)/0.47
					var skin: Vector3 = CompactCoachwork.cabin_front_point(point.x/CompactCoachwork.cabin_width(height), height)
					clearance = minf(clearance, (point-skin).dot(Vector3(0,0.79,-0.61).normalized()))
				check(clearance>0.004, "windshield stays outside the cowl and cabin")
		if DisplayServer.get_name() != "headless":
			for pose: Array in [["side", Vector3(6, 1.1, 0)], ["front", Vector3(0, 2.6, -6)], ["front-quarter", Vector3(-4, 2.8, -5)], ["overhead", Vector3(-2.8, 6, -4)]]:
				camera.position = pose[1]
				camera.look_at(Vector3(0, 0.8, 0))
				for frame: int in range(8): await process_frame
				await RenderingServer.frame_post_draw
				var path: String = output.path_join(("simple-" if simple else "standard-") + pose[0] + ".png")
				check(root.get_texture().get_image().save_png(path)==OK, "capture " + path.get_file())
		car.free()
		await process_frame
	if validate:
		var original = load("res://../docs/evidence/rally-windows-2026-11-08/before/game/vehicle/compact_glazing.gd")
		var current = preload("res://vehicle/compact_glazing.gd")
		var rear_exact: bool = true
		for front: bool in [false, true]:
			for u: float in [-1.0, -0.9, -0.4, 0.0, 0.4, 0.9, 1.0]:
				check(current.windshield_point(front,u,0.5).distance_to((current.windshield_point(front,u,0.0)+current.windshield_point(front,u,1.0))*0.5)<0.0002, "glass retains straight vertical generators")
			var center: Vector3 = current.windshield_point(front,0.0,0.5)
			var chord: Vector3 = (current.windshield_point(front,-1.0,0.5)+current.windshield_point(front,1.0,0.5))*0.5
			check(absf(center.distance_to(chord)-(0.008 if front else 0.018))<0.0002, "authored cross-car curvature")
		for row: int in range(21):
			for column: int in range(37):
				for glass: bool in [false, true]:
					rear_exact = rear_exact and Vector3(original._sheet_point(false, column/36.0, row/20.0, glass)).is_equal_approx(current._sheet_point(false, column/36.0, row/20.0, glass))
		check(rear_exact, "rear glass and gasket keep the original shape")
	world.free()
	print("RALLY_WINDOWS: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
