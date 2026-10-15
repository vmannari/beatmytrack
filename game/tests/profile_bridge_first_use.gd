extends SceneTree
const BridgePreparation = preload("res://track/bridge_render_preparation.gd")
## Isolate the owner's exact bridge materials; never advance or save a race.
var game: Node
var rows: Array[Dictionary] = []
var bridge_nodes: Array[MeshInstance3D] = []
var draw_started: int = 0
var last_draw_us: int = 0
var output: String = "res://../docs/evidence/bridge-first-use-2026-10-14"

func _initialize() -> void: run.call_deferred()

func pre_draw() -> void: draw_started = Time.get_ticks_usec()
func post_draw() -> void: last_draw_us = Time.get_ticks_usec() - draw_started

func frames(count: int) -> void:
	for index: int in range(count): await RenderingServer.frame_post_draw

func measure(label: String, names: Array[String]) -> void:
	for node: MeshInstance3D in bridge_nodes: node.visible = str(node.name) in names
	for index: int in range(6):
		var started: int = Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		rows.append({"phase": label, "frame": index, "interval_ms": (Time.get_ticks_usec() - started) / 1000.0, "draw_ms": last_draw_us / 1000.0})
	await frames(4)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Bridge first-use probe needs a graphical renderer")
		quit(1)
		return
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var only: String = "all"
	for arg: String in args:
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	if only not in ["all", "road", "shadow", "steel"]:
		push_error("--only must be all, road, shadow or steel")
		quit(1)
		return
	root.size = Vector2i(1346, 720)
	var document: Dictionary = TrackLibrary.new().import_document(ProjectSettings.globalize_path("res://../build/bridge-first-use-2026-10-14/track-document.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	if track == null or track.creator_bridges.is_empty():
		push_error("Expected the cached Silmukka bridge track")
		quit(1)
		return
	game = load("res://core/game.tscn").instantiate()
	game.initial_track = track
	game.production_mode = true
	game.hitch_diagnostics_enabled = false
	game.preference_records = LocalRecords.new(ProjectSettings.globalize_path("res://../build/bridge-first-use-2026-10-14/disposable-records.json"))
	root.add_child(game)
	game.paused = true
	game.call("_process", 0.0)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	for name: String in ["BridgeUnderShadow", "BridgeAsphalt", "BridgeSteelAndFascia"]:
		for node: Node in game.find_children(name, "MeshInstance3D", true, false):
			bridge_nodes.append(node)
			node.visible = false
	var condition: Dictionary = game.car_weathering.snapshot()
	var state: Dictionary = RewindHistory.properties(game.sim.state)
	var camera: Camera3D = game.camera
	var pose: Transform3D = camera.transform
	var original_size: float = camera.size
	var span: Dictionary = track.creator_bridges[0]
	var midpoint: Vector2 = Vector2(span.position[0], span.position[1]) + Vector2(float(span.length) * 0.5, 0).rotated(deg_to_rad(float(span.heading)))
	camera.position.x = midpoint.x
	camera.position.z = -midpoint.y + 23.0
	camera.position.y = 38.0
	camera.look_at(Vector3(midpoint.x, 1.5, -midpoint.y))
	camera.size = 54.0
	RenderingServer.frame_pre_draw.connect(pre_draw)
	RenderingServer.frame_post_draw.connect(post_draw)
	await frames(60)
	await measure("hidden_baseline", [])
	var selected: Array[String] = ["BridgeUnderShadow", "BridgeAsphalt", "BridgeSteelAndFascia"]
	if only == "shadow": selected = ["BridgeUnderShadow"]
	elif only == "road": selected = ["BridgeAsphalt"]
	elif only == "steel": selected = ["BridgeSteelAndFascia"]
	if "--specialize" in args:
		for node: MeshInstance3D in bridge_nodes:
			if node.name == "BridgeAsphalt": SurfaceShaderVariants.specialize(node.material_override)
	if "--warm" in args:
		var bridge_pose: Transform3D = camera.transform
		camera.transform = pose
		camera.size = original_size
		for node: MeshInstance3D in bridge_nodes: node.visible = str(node.name) in selected
		await frames(4)
		var restore: Array[Dictionary] = BridgePreparation.begin(game.track_ground, camera)
		for index: int in range(2):
			var started: int = Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			rows.append({"phase": "loading_preparation", "frame": index, "interval_ms": (Time.get_ticks_usec() - started) / 1000.0, "draw_ms": last_draw_us / 1000.0, "meshes": restore.size()})
		BridgePreparation.end(restore)
		await frames(4)
		camera.transform = bridge_pose
		camera.size = 54.0
	await measure("first_visible", selected)
	await measure("hidden_again", [])
	await measure("repeat_visible", selected)
	var report: Dictionary = {"renderer": RenderingServer.get_current_rendering_method(), "adapter": RenderingServer.get_video_adapter_name(), "track_hash": track.content_hash, "matches_live_track": track.content_hash == "11bc2da60320c9b3e047b88c2dbf36ff22a7c20affb2ac03d48873e1ab4f68fb", "bridge_count": track.creator_bridges.size(), "only": only, "warm": "--warm" in args, "specialized": "--specialize" in args, "state_exact": RewindHistory.properties(game.sim.state) == state, "condition_exact": game.car_weathering.snapshot() == condition, "countdown_ticks": game.countdown_ticks, "rows": rows}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.get_texture().get_image().save_png(output.path_join("probe-%s-%s-%d.png" % [report.renderer, only, OS.get_process_id()]))
	var file := FileAccess.open(output.path_join("probe-%s-%s-%d.json" % [report.renderer, only, OS.get_process_id()]), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("BRIDGE_FIRST_USE ", JSON.stringify(report))
	camera.transform = pose
	game.free()
	quit(0 if report.state_exact and report.condition_exact and report.matches_live_track else 1)
