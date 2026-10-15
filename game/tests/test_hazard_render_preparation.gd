extends SceneTree
## Actual offscreen hazard draws and covered app launch; disposable records only.
const Preparation = preload("res://track/bridge_render_preparation.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func frames(count: int = 4) -> void:
	for index: int in range(count):
		if DisplayServer.get_name() == "headless": await process_frame
		else: await RenderingServer.frame_post_draw

func run() -> void:
	root.size = Vector2i(960, 540)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	world.add_child(camera)
	camera.position = Vector3(0, 12, 10)
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-50, -25, 0)
	for index: int in range(4):
		HazardVisual.build(world, {"kind": ["jump", "puddle", "oil", "speed_bump"][index], "position": [float(index)*30, 0.0], "rotation": 15.0, "scale": 1.0})
	var hazards: Array[Node] = get_nodes_in_group("race_hazard_rendering")
	check(hazards.size() == 4, "all actual hazard kinds retain preparation membership despite duplicate native names")
	var snapshots: Array[Dictionary] = []
	for node: MeshInstance3D in hazards:
		snapshots.append({"node": node, "mesh": node.mesh, "material": node.material_override, "pose": node.transform, "margin": node.extra_cull_margin, "shadow": node.cast_shadow, "layers": node.layers})
	await frames(120 if DisplayServer.get_name() != "headless" else 4)
	var image: Image = root.get_texture().get_image() if DisplayServer.get_name() != "headless" else null
	var camera_pose: Transform3D = camera.transform
	var restore: Array[Dictionary] = Preparation.begin_groups(world, camera, ["race_hazard_rendering"])
	check(restore.size() == 4, "covered draw includes offscreen hazard meshes")
	await frames()
	Preparation.end(restore)
	Preparation.end(restore)
	await frames()
	for entry: Dictionary in snapshots:
		var node: MeshInstance3D = entry.node
		check(node.mesh == entry.mesh and node.material_override == entry.material and node.transform == entry.pose and node.extra_cull_margin == entry.margin and node.cast_shadow == entry.shadow and node.layers == entry.layers, "actual hazard geometry/material/pose/shadow/layers/cull bounds restore exactly")
	check(camera.transform == camera_pose and camera.size == 20.0, "preparation retains the exact camera")
	if image != null:
		var after: Image = root.get_texture().get_image()
		check(image.get_data() == after.get_data(), "restored hazard pixels are byte exact")
		var output: String = "res://../docs/evidence/desert-hitch-2026-10-13/hazard-preparation/" + RenderingServer.get_current_rendering_method()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		image.save_png(output.path_join("before.png"))
		after.save_png(output.path_join("after.png"))
	(hazards[0] as MeshInstance3D).visible = false
	restore = Preparation.begin_groups(world, camera, ["race_hazard_rendering"])
	check(restore.size() == 3, "preparation preserves hidden hazard state")
	Preparation.end(restore)
	restore = Preparation.begin_groups(world, camera, ["race_hazard_rendering"])
	world.free()
	Preparation.end(restore)
	check(restore.is_empty(), "cancelled preparation safely releases deleted hazard nodes")
	await frames(1)
	await app_launch()
	print("HAZARD_PREPARATION_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func app_launch() -> void:
	OS.set_environment("BMT_API_URL", "")
	var folder: String = "user://hazard_preparation_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
	document.objects = [{"kind": "jump", "position": [0.0, 0.0], "rotation": 0.0, "scale": 1.0}, {"kind": "jump", "position": [30.0, 0.0], "rotation": 0.0, "scale": 1.0}, {"kind": "jump", "position": [-30.0, 0.0], "rotation": 0.0, "scale": 1.0}]
	var track: NativeTrack = TrackCompiler.compile(document)
	track.metadata.cloud_version = "isolated-hazard-preparation"
	app.selected_track = track
	var retained_finish := VehicleWeathering.new()
	retained_finish.deposit_color = VehicleWeathering.COLORS.pine
	retained_finish.dirt_amount = 0.125
	check(VehicleCondition.save(app.records, VehicleCatalog.selected, retained_finish.snapshot()) == OK, "fixture has an existing local car condition")
	var condition: Dictionary = app.records.settings.vehicle_conditions.duplicate(true)
	app._start_race(track, false, true)
	var revealed: Dictionary = {}
	app.race_loading.tree_exiting.connect(func() -> void:
		if is_instance_valid(app.game):
			revealed.tick = app.game.sim.state.tick
			revealed.countdown = app.game.countdown_ticks)
	var began: int = Time.get_ticks_msec()
	while app.cloud_starting and Time.get_ticks_msec()-began < 15000: await process_frame
	check(is_instance_valid(app.game) and not app.cloud_starting, "actual covered hazard race completes")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		check(revealed.get("tick", -1) == 0 and revealed.get("countdown", -1) == 360, "covered hazard preparation consumes no simulation/countdown ticks")
		check(app.game.hazards_prepared == (DisplayServer.get_name() != "headless") and app.game.hazard_preparation_meshes == (3 if DisplayServer.get_name() != "headless" else 0), "app reports actual hazard draw rather than headless preloading")
		check(get_nodes_in_group("race_hazard_rendering").all(func(node: Node) -> bool: return is_zero_approx(node.extra_cull_margin)), "race releases every temporary hazard cull margin")
		check(app.records.settings.get("vehicle_conditions", {}) == condition, "covered hazard draw preserves local car condition")
		app._leave_race()
	app.queue_free()
	await frames(1)
