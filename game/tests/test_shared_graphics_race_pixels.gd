extends SceneTree
## Replay task-start/shared staging on the same actual race, at canonical tick zero.
const Queue = preload("res://race/world_render_preparation.gd")
const Before = preload("res://../docs/evidence/graphics-preparation-2026-11-04/before/game/race/world_render_preparation.gd")
const Shared = preload("res://rendering/graphics_preparation.gd")
var app: Node
var checks: int = 0
var failures: int = 0
var rows: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("GRAPHICS_RACE_PIXELS_FAIL ",label)
func draw() -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	return true
func run() -> void:
	create_timer(220,true,false,true).timeout.connect(func() -> void: printerr("GRAPHICS_RACE_PIXELS_TIMEOUT"); quit(1))
	root.size = Vector2i(1280,720)
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new("user://graphics-race-pixels/records.json")
	app.records.settings.music_enabled = false
	app.library = TrackLibrary.new("user://graphics-race-pixels/tracks")
	app.cloud_root_override = "user://graphics-race-pixels/cloud"
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._garage_preloader.idle_ms = 100000000
	app._garage_preloader.foreground = false
	Engine.time_scale = 0.0
	for theme: String in ["pine","winter"]:
		var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
		document.theme = theme
		var track: NativeTrack = TrackCompiler.compile(document)
		track.metadata.cloud_version = "owned-graphics-pixel-check"
		app._show_screen("tracks")
		app.selected_track = track
		await app._start_race(track,false,true)
		check(is_instance_valid(app.game),"actual race installs "+theme)
		if not is_instance_valid(app.game): quit(1); return
		var game: Node = app.game
		game.process_mode = Node.PROCESS_MODE_DISABLED
		game.set_physics_process(false)
		game.hitch_diagnostics.persist_enabled = false
		for _i: int in range(6): await draw()
		var reference: Image = root.get_texture().get_image()
		check(reference.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join(theme+"-reference.png")) == OK,"native actual race reference")
		for control: bool in [true,false]:
			Before.warmed.clear()
			Shared.invalidate()
			var queue: Node = Before.new() if control else Queue.new()
			game.add_child(queue)
			queue.hold(game.get_node("World"))
			var began: int = Time.get_ticks_usec()
			check(await queue.prepare(draw,func() -> bool: return true),"native race replay finishes "+theme+str(control))
			var elapsed: float = (Time.get_ticks_usec()-began)/1000.0
			for _i: int in range(4): await draw()
			var image: Image = root.get_texture().get_image()
			check(reference.get_data() == image.get_data(),"exact same-owner full race pixels "+theme+str(control))
			check(image.save_png(OS.get_environment("BMT_GRAPHICS_EVIDENCE").path_join(theme+"-"+str(control)+".png")) == OK,"native race replay capture")
			check(game.sim.state.tick == 0 and game.countdown_ticks == 360 and game.track_session.target_laps == 5,"canonical start and full countdown retained")
			rows.append({"theme":theme,"control":control,"draws":queue.frame_groups,"ms":elapsed,"exact":reference.get_data() == image.get_data()})
			queue.free()
		app._leave_race()
		for _i: int in range(4): await process_frame
	app.queue_free()
	app = null
	Engine.time_scale = 1.0
	for _i: int in range(16): await process_frame
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"renderer":RenderingServer.get_current_rendering_method()},"  "))
	print("GRAPHICS_RACE_PIXELS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
