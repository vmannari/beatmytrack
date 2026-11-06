extends SceneTree
## Actual App entry, cancellation and ownership in isolated offline storage.
var app: Node
var checks: int = 0
var failures: int = 0
var observations: Dictionary = {}

func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FEATURE_NAV_FAIL ",label)
func frames(count: int = 1) -> void:
	for _i: int in range(count):
		if is_instance_valid(app):
			app._publishing_slots_foreground = true
			if is_instance_valid(app._garage_preloader): app._garage_preloader.foreground = true
		await process_frame
func settle_requests() -> void:
	var deadline: int = Time.get_ticks_msec()+30000
	while app._feature_load_pending > 0 and Time.get_ticks_msec()<deadline: await frames()
	check(app._feature_load_pending == 0,"requested resources settle without blocking")
	await frames(2)
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("BMT_GRAPHICS_OUTPUT")
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)

func run() -> void:
	root.size = Vector2i(1280,720)
	create_timer(180,true,false,true).timeout.connect(func() -> void: printerr("FEATURE_NAV_TIMEOUT"); quit(1))
	app = load("res://core/app.gd").new()
	app.name = "CircuitApp"
	app.records = load("res://persistence/local_records.gd").new("user://feature-navigation/records.json")
	app.records.settings.music_enabled = false
	app.library = load("res://persistence/track_library.gd").new("user://feature-navigation/tracks")
	app.cloud_root_override = "user://feature-navigation/cloud"
	root.add_child(app)
	while not app.startup_complete: await frames()
	app._garage_preloader.set_process(false)
	app._publishing_slots_foreground = false
	check(app.screen == "account" and not app.online.configured,"private offline first menu")
	check(app._feature_resources.is_empty(),"first menu keeps optional controllers unloaded")
	var began: int = Time.get_ticks_usec()
	app._show_screen("garage")
	observations.garage_entry_call_ms = (Time.get_ticks_usec()-began)/1000.0
	check(is_instance_valid(app._feature_loading) and app.screen == "account","cold Garage presents cover before resource load")
	check(not app._feature_resources.has("res://core/features/garage.gd") and not is_instance_valid(app._retained_garage),"cover needs no Garage controller or scene")
	await capture("garage-cover")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape,true)
	await frames(3)
	check(not is_instance_valid(app._feature_loading) and app.screen == "account","Cancel preserves the previous menu")
	await settle_requests()
	check(not app._feature_resources.has("res://core/features/garage.gd") and not is_instance_valid(app._retained_garage),"cancelled load cannot publish a Garage")
	app._show_screen("garage")
	await frames()
	app._show_screen("settings")
	await settle_requests()
	check(app.screen == "settings" and not is_instance_valid(app._retained_garage),"new navigation supersedes unfinished entry")
	await app._show_screen("garage")
	check(app.screen == "garage" and is_instance_valid(app._retained_garage),"retry installs one real Garage")
	var garage: Node = app._retained_garage
	app._show_screen("settings")
	await app._show_screen("garage")
	check(app._retained_garage == garage and not is_instance_valid(app._feature_loading),"warm Garage reuses page without a loading cover")
	app._show_screen("account")
	app.document = load("res://editor/track_document.gd").create_default()
	var owner: RefCounted = app.records
	app._show_screen("create")
	check(is_instance_valid(app._feature_loading) and not is_instance_valid(app.canvas),"Editor cover precedes authoring controls")
	await capture("editor-cover")
	app.records = load("res://persistence/local_records.gd").new("user://feature-navigation/replaced-owner.json")
	await settle_requests()
	check(not is_instance_valid(app.canvas) and not is_instance_valid(app._feature_loading),"owner replacement cancels Editor entry")
	app.records = owner
	await app._show_screen("create")
	check(app.screen == "create" and is_instance_valid(app.canvas) and app.canvas.document == app.document,"Editor retry preserves the exact document")
	app._show_screen("account")
	var track: RefCounted = load("res://track/native_track.gd").read("res://resources/tracks/ellipse.json")
	track.metadata.cloud_version = "feature-navigation"
	app.selected_track = track
	check(not app._feature_resources.has("res://core/features/race.gd"),"race controller remains cold after menu entries")
	began = Time.get_ticks_usec()
	app._start_race(track,false,true)
	observations.race_entry_call_ms = (Time.get_ticks_usec()-began)/1000.0
	var loading: Node = app.race_loading
	check(is_instance_valid(loading) and app.game == null,"race cover precedes race controller and Game loading")
	check(not app._feature_resources.has("res://core/features/race.gd"),"race loading cover is shell-owned")
	app._start_race(track,false,true)
	check(app.race_loading == loading,"duplicate race tap owns one cover")
	await capture("race-cover")
	app._show_screen("settings")
	await settle_requests()
	check(app.game == null and app.race_loading == null and not app.cloud_starting and app.screen == "settings","navigation cancels a cold race without a hidden Game")
	observations.checks = checks
	observations.failures = failures
	observations.feature_load_ms = app.feature_load_ms.duplicate()
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(observations,"  "))
	print("FEATURE_NAVIGATION ",JSON.stringify(observations))
	app.queue_free()
	app = null
	await frames(24)
	quit(1 if failures else 0)
