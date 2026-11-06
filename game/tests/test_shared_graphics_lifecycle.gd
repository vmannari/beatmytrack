extends SceneTree
## Interrupt the actual App's world queue, including after a real submission.
const Shared = preload("res://rendering/graphics_preparation.gd")
var app: Node
var mode: String
var interrupted: bool = false
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("GRAPHICS_LIFECYCLE_FAIL ",label)
func observe() -> void:
	if interrupted or not is_instance_valid(app) or not is_instance_valid(app.game): return
	var queue: Node = app.game.world_render_preparation
	if not is_instance_valid(queue) or queue.pending.is_empty() or queue.frame_groups < 1: return
	interrupted = true
	match mode:
		"navigation": app._show_screen("settings")
		"car": VehicleCatalog.selected = "kart"
		"selection": app.selected_track = NativeTrack.new()
		"scope": app.online.client.configure("http://127.0.0.1:1")
		"teardown": app.queue_free()
func run() -> void:
	create_timer(180).timeout.connect(func() -> void: printerr("GRAPHICS_LIFECYCLE_TIMEOUT"); quit(1))
	root.size = Vector2i(960,540)
	app = load("res://core/app.tscn").instantiate()
	if "--control" in OS.get_cmdline_user_args():
		var scene: PackedScene = preload("res://tests/graphics_control_scene.gd").create()
		if scene == null: quit(1); return
		app._feature_resources["res://core/game.tscn"] = scene
	app.records = LocalRecords.new("user://graphics-lifecycle/records.json")
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new("user://graphics-lifecycle/tracks")
	app.cloud_root_override = "user://graphics-lifecycle/cloud"
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	track.metadata.cloud_version = "owned-graphics-lifecycle"
	process_frame.connect(observe)
	for action: String in ["navigation","car","selection","scope","teardown"]:
		mode = action
		interrupted = false
		Shared.invalidate()
		VehicleCatalog.selected = "compact"
		app.online.client.configure("")
		app._show_screen("tracks")
		app.selected_track = track
		app._start_race(track,false,true)
		while is_instance_valid(app) and (not interrupted or is_instance_valid(app.game) or is_instance_valid(app.race_loading)): await process_frame
		for _i: int in range(8): await process_frame
		check(interrupted,"actual world submission interrupted "+action)
		if action == "teardown": check(not is_instance_valid(app),"App and its native preparation release")
		else: check(not is_instance_valid(app.game) and not is_instance_valid(app.race_loading) and not app.cloud_starting,"abandoned graphics cannot activate "+action)
	process_frame.disconnect(observe)
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	print("GRAPHICS_LIFECYCLE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
