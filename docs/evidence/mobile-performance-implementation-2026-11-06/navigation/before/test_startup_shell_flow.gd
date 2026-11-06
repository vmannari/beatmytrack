extends SceneTree
## Render real feature entry using task-before or shipping App in private storage.
var app: Node
var checks: int = 0
var failures: int = 0
var output: String
var observations: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("SHELL_FLOW_FAIL ",message)
func frames(count: int = 4) -> void:
	for _i: int in range(count):
		if is_instance_valid(app):
			app._publishing_slots_foreground = true
			if is_instance_valid(app._garage_preloader): app._garage_preloader.foreground = true
		await process_frame
func settle() -> void:
	app._stop_menu_page_motion()
	await frames(8)
func shot(label: String) -> void:
	await settle()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native capture "+label)

func run() -> void:
	root.size = Vector2i(1280,720)
	create_timer(240,true,false,true).timeout.connect(func() -> void: printerr("SHELL_FLOW_TIMEOUT"); quit(1))
	output = OS.get_environment("BMT_LOADING_OUTPUT").get_basename()+"-views"
	DirAccess.make_dir_recursive_absolute(output)
	var before: bool = "--before" in OS.get_cmdline_user_args()
	var script: Script = load("res://../docs/evidence/startup-shell-2026-11-04/before/game/core/app.gd" if before else "res://core/app.gd")
	app = script.new()
	app.name = "CircuitApp"
	var records: RefCounted = load("res://persistence/local_records.gd").new("user://shell-flow/records.json")
	DirAccess.make_dir_recursive_absolute(records.path.get_base_dir())
	records.settings.music_enabled = false
	check(records.save_records() == OK,"private silent fixture saved")
	app.records = records
	app.library = load("res://persistence/track_library.gd").new("user://shell-flow/tracks")
	app.cloud_root_override = "user://shell-flow/cloud"
	root.add_child(app)
	while not app.startup_complete:
		app._publishing_slots_foreground = true
		await process_frame
	check(app.screen == "account" and not app.online.configured,"offline account destination")
	app._garage_preloader.set_process(false)
	if "--cold-garage" in OS.get_cmdline_user_args(): app._garage_preloader.evict()
	Engine.time_scale = 0.0
	await shot("account")
	var compiler: Script = load("res://editor/track_compiler.gd")
	var documents: Script = load("res://editor/track_document.gd")
	var fixture: Dictionary = documents.create_default()
	fixture.name = "Shell fixture"
	var track: RefCounted = compiler.compile(fixture)
	check(track != null,"valid compiled flow fixture")
	if track == null: quit(1); return
	track.metadata.cloud_version = "shell-fixture"
	app.selected_track = track
	app.race_area_mode = "free"
	app._show_screen("tracks")
	check(app.root_ui.find_child("TrackBrowser",true,false) != null,"Free Race builds its existing page")
	await shot("tracks")
	var began: int = Time.get_ticks_usec()
	await app._start_race(track,false,true)
	observations.race_ms = (Time.get_ticks_usec()-began)/1000.0
	check(is_instance_valid(app.game),"Race module installs Game")
	if not is_instance_valid(app.game): quit(1); return
	app.game.set_physics_process(false)
	app.game.hitch_diagnostics.persist_enabled = false
	check(app.game.preparation_complete,"native race preparation completes")
	check(app.game.sim.state.tick == 0 and app.game.countdown_ticks == 360,"full countdown and canonical tick zero")
	check(app.game.track_session.target_laps == 5,"five laps retained")
	app.game._process(0.0)
	await shot("race")
	app._leave_race()
	app.document = fixture.duplicate(true)
	app._show_screen("create")
	await settle()
	check(is_instance_valid(app.canvas) and is_instance_valid(app.editor_world),"Editor module installs real authoring controls and world")
	check(app.canvas.document == app.document,"editor retains canonical document ownership")
	app._remember()
	var name: String = str(app.document.name)
	app.document.name = "Changed"
	app._undo()
	check(str(app.document.name) == name,"editor history survives delegation")
	while app.editor_preview_thread != null or app.canvas.native_preview == null or app.editor_world._building or app.editor_commits.unsettled(): await frames(1)
	check(app.editor_world._initial_preparation_done and app.canvas.native_preview != null,"native editor world finishes preparation")
	await shot("editor")
	app._show_screen("garage")
	app._stop_menu_page_motion()
	var page: Control = app._retained_garage
	check(is_instance_valid(page),"Garage module installs existing page")
	began = Time.get_ticks_usec()
	while page.progressive_entry and page.showroom.preparing: await frames(1)
	observations.garage_ms = (Time.get_ticks_usec()-began)/1000.0
	check(page.showroom.showroom_ready and page.showroom.car != null,"full live Garage ready")
	check(page.showroom.reflections.views.size() == 2,"both real reflections retained")
	check(page.showroom.car.vehicle_id == "compact","correct Garage vehicle")
	await shot("garage")
	var old_page: WeakRef = weakref(page)
	app._show_screen("settings")
	await settle()
	app._show_screen("garage")
	check(app._retained_garage == page,"Garage revisit retains its live page")
	app._show_screen("account")
	app.records = load("res://persistence/local_records.gd").new("user://shell-flow/other-owner.json")
	app._publishing_slots_foreground = false
	app._show_screen("garage")
	check(app._retained_garage != page and app._retained_garage.records == app.records,"owner change fences Garage state")
	page = null
	await frames(8)
	check(old_page.get_ref() == null,"old owner releases native Garage")
	observations.checks = checks
	observations.failures = failures
	observations.before = before
	if not before: observations.feature_load_ms = app.feature_load_ms.duplicate(true)
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(observations,"  "))
	print("SHELL_FLOW ",JSON.stringify(observations))
	app.queue_free()
	app = null
	await frames(16)
	quit(1 if failures else 0)
