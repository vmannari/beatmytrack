extends SceneTree
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
	var output: String = ProjectSettings.globalize_path("res://../docs/evidence/bridge-first-use-2026-10-14/preparation-" + RenderingServer.get_current_rendering_method())
	DirAccess.make_dir_recursive_absolute(output)
	for theme: String in TrackTheme.IDS + ["native", "no-bridge"]:
		if "--night-only" in OS.get_cmdline_user_args() and theme != "night_city": continue
		var track: NativeTrack
		if theme == "native": track = NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_1way_test.json")
		elif theme == "no-bridge": track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
		else:
			var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/over_and_under.json"))
			document.theme = theme
			track = TrackCompiler.compile(document)
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = track
		game.production_mode = true
		game.preference_records = LocalRecords.new(output.path_join("disposable-records.json"))
		root.add_child(game)
		game.hitch_diagnostics.persist_enabled = false
		game.paused = true
		game.call("_process", 0.0)
		game.process_mode = Node.PROCESS_MODE_DISABLED
		await frames(120 if DisplayServer.get_name() != "headless" else 4)
		var camera: Camera3D = game.camera
		var camera_pose: Transform3D = camera.transform
		var camera_size: float = camera.size
		var state: Dictionary = RewindHistory.properties(game.sim.state)
		var condition: Dictionary = game.car_weathering.snapshot()
		var before: Image
		if DisplayServer.get_name() != "headless": before = root.get_texture().get_image()
		var restore: Array[Dictionary] = Preparation.begin(game.track_ground, camera)
		check(not restore.is_empty() if theme != "no-bridge" else restore.is_empty(), theme + " prepares only existing bridge meshes")
		var snapshots: Array[Dictionary] = []
		for entry: Dictionary in restore:
			var node: MeshInstance3D = entry.node
			snapshots.append({"node": node, "mesh": node.mesh, "material": node.material_override, "pose": node.transform, "margin": entry.margin, "shadow": node.cast_shadow, "layers": node.layers, "visible": node.visible})
			check(node.extra_cull_margin >= node.to_local(camera.global_position).distance_to(node.get_aabb().get_center()) / sqrt(3.0), theme + " includes the starting camera in the preparation bounds")
		await frames()
		Preparation.end(restore)
		Preparation.end(restore)
		await frames()
		var retained: bool = true
		for snapshot: Dictionary in snapshots:
			var node: MeshInstance3D = snapshot.node
			retained = retained and node.mesh == snapshot.mesh and node.material_override == snapshot.material and node.transform == snapshot.pose and node.extra_cull_margin == snapshot.margin and node.cast_shadow == snapshot.shadow and node.layers == snapshot.layers and node.visible == snapshot.visible
		check(retained and restore.is_empty(), theme + " restores exact bounds, meshes, materials, frames, shadows and visibility")
		check(camera.transform == camera_pose and camera.size == camera_size, theme + " retains the exact gameplay camera")
		check(RewindHistory.properties(game.sim.state) == state and game.countdown_ticks == 360 and game.car_weathering.snapshot() == condition, theme + " retains canonical state, full countdown and local condition")
		if before != null:
			var after: Image = root.get_texture().get_image()
			check(before.get_data() == after.get_data(), theme + " restores byte-exact pixels")
			before.save_png(output.path_join(theme + "-before.png"))
			after.save_png(output.path_join(theme + "-after.png"))
		if not snapshots.is_empty():
			var hidden: MeshInstance3D = snapshots[0].node
			hidden.visible = false
			var limited: Array[Dictionary] = Preparation.begin(game.track_ground, camera)
			check(not limited.any(func(entry: Dictionary) -> bool: return entry.node == hidden), theme + " preserves hidden bridge groups")
			Preparation.end(limited)
			hidden.visible = true
		var cancellation: Array[Dictionary] = Preparation.begin(game.track_ground, camera)
		game.free()
		Preparation.end(cancellation)
		check(cancellation.is_empty(), theme + " safely restores after scene cancellation")
		await frames(1)
	print("BRIDGE_PREPARATION_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
