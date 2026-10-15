extends SceneTree
## Actual ribbon draw, untouched race ring, restored pixels and covered app start.
const Preparation = preload("res://vehicle/trail_render_preparation.gd")
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

func ring_snapshot(trails: SkidTrails) -> Dictionary:
	return {"resource": trails.instances, "buffer": trails.instances.buffer, "count": trails.instances.visible_instance_count,
		"cursor": trails.cursor, "active": trails.active, "colors": trails.mark_colors.duplicate(), "custom": trails.mark_custom.duplicate(),
		"poses": trails.mark_transforms.duplicate(), "previous": trails._previous_marks.duplicate(), "sides": trails._previous_sides.duplicate(),
		"ends": trails._previous_ends.duplicate(), "types": trails._previous_types.duplicate(), "sand": trails.desert_sand,
		"bridge": trails._bridge_track, "material": trails._bridge_material, "shader": trails._bridge_material.shader,
		"bridge_count": trails._bridge_material.get_shader_parameter("dust_bridge_count"), "material_sand": trails._bridge_material.get_shader_parameter("desert_sand_trails")}

func run() -> void:
	root.size = Vector2i(960, 540)
	var output: String = "res://../docs/evidence/tire-first-draw-2026-10-14"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): output = argument.trim_prefix("--folder=").trim_suffix("/")
	for theme: String in ["pine", "winter", "desert"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
		document.theme = theme
		var track: NativeTrack = TrackCompiler.compile(document)
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = track
		game.production_mode = true
		root.add_child(game)
		game.hitch_diagnostics.persist_enabled = false
		game.paused = true
		game.call("_process", 0.0)
		game.process_mode = Node.PROCESS_MODE_DISABLED
		var trails: SkidTrails = game.trails
		trails.sample(game.sim.state, DriveFrame.new(), game.bridge_presentation, track)
		# Preserve real pre-existing joined marks as well as a fresh empty ring.
		for index: int in range(4):
			trails._mark(Vector3(float(index), 0.03, 0), Vector3(float(index), 0.03, 0.8), 0.0, 2, 0.58, index)
		await frames(120 if DisplayServer.get_name() != "headless" else 4)
		var before: Dictionary = ring_snapshot(trails)
		var state: Dictionary = RewindHistory.properties(game.sim.state)
		var condition: Dictionary = game.car_weathering.snapshot()
		var camera_pose: Transform3D = game.camera.transform
		var image: Image = root.get_texture().get_image() if DisplayServer.get_name() != "headless" else null
		var batch: MultiMeshInstance3D = Preparation.begin(trails, game.camera, track, game.sim.state)
		check((batch != null) == (DisplayServer.get_name() != "headless"), theme + " prepares actual rendering only")
		if batch != null:
			check(batch.multimesh.mesh == trails.instances.mesh and batch.material_override.shader == trails._bridge_material.shader, theme + " shares the exact live mesh and Shader RID")
			check(batch.multimesh.instance_count == 1 and batch.multimesh.visible_instance_count == 1 and batch.multimesh.use_colors == trails.instances.use_colors and batch.multimesh.use_custom_data == trails.instances.use_custom_data and batch.multimesh.transform_format == trails.instances.transform_format, theme + " keeps the same instance format with one temporary slot")
		await frames()
		check(ring_snapshot(trails) == before, theme + " covered draw leaves the entire race ring/material/history unchanged")
		if image != null:
			check(root.get_texture().get_image().get_data() != image.get_data(), theme + " actual ribbon reaches visible pixels before teardown")
		Preparation.end(batch)
		await frames()
		check(ring_snapshot(trails) == before and trails.instances.instance_count == 16384, theme + " teardown retains exact full-capacity ring")
		check(RewindHistory.properties(game.sim.state) == state and game.countdown_ticks == 360 and game.car_weathering.snapshot() == condition and game.camera.transform == camera_pose, theme + " retains canonical state/countdown/condition/camera")
		check(trails.get_children().filter(func(node: Node) -> bool: return node is MultiMeshInstance3D).size() == 1, theme + " racing retains its original single MultiMesh draw")
		if image != null:
			var after: Image = root.get_texture().get_image()
			check(after.get_data() == image.get_data(), theme + " restored race pixels are byte exact")
			var folder: String = output + "/" + RenderingServer.get_current_rendering_method()
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			image.save_png(folder.path_join(theme + "-before.png"))
			after.save_png(folder.path_join(theme + "-after.png"))
		trails.hide()
		check(Preparation.begin(trails, game.camera, track, game.sim.state) == null, theme + " retains hidden render state")
		trails.show()
		batch = Preparation.begin(trails, game.camera, track, game.sim.state)
		game.free()
		Preparation.end(batch)
		check(not is_instance_valid(batch), theme + " cancellation releases the temporary draw")
		await frames(1)
	await app_launch()
	print("TRAIL_PREPARATION_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func app_launch() -> void:
	OS.set_environment("BMT_API_URL", "")
	var folder: String = "user://trail_preparation_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	var track: NativeTrack = TrackCompiler.compile(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json")))
	track.metadata.cloud_version = "isolated-trail-preparation"
	app.selected_track = track
	app._start_race(track, false, true)
	var revealed: Dictionary = {}
	app.race_loading.tree_exiting.connect(func() -> void:
		if is_instance_valid(app.game):
			revealed.tick = app.game.sim.state.tick
			revealed.countdown = app.game.countdown_ticks)
	var began: int = Time.get_ticks_msec()
	while app.cloud_starting and Time.get_ticks_msec()-began < 15000: await process_frame
	check(is_instance_valid(app.game) and not app.cloud_starting, "actual covered race launch completes")
	if is_instance_valid(app.game):
		app.game.set_physics_process(false)
		check(revealed.get("tick", -1) == 0 and revealed.get("countdown", -1) == 360, "preparation consumes no simulation/countdown ticks")
		check(app.game.trails_prepared == (DisplayServer.get_name() != "headless"), "app reports an actual covered tire draw")
		check(app.game.trails.cursor == 0 and app.game.trails.instances.visible_instance_count == 0 and app.game.trails.instances.instance_count == 16384, "normal launch contains no fabricated marks")
		check(app.game.trails.get_children().filter(func(node: Node) -> bool: return node is MultiMeshInstance3D).size() == 1, "normal launch has one tire batch")
		app._leave_race()
	app.queue_free()
	await frames(1)
