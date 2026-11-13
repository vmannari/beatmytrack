extends SceneTree
## Actual Settings/garage/race flow with isolated local records and no service writes.
var checks: int = 0
var failures: int = 0
var output: String
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func settle() -> void:
	for frame: int in range(8): await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	OS.set_environment("BMT_API_URL","")
	output = "res://../docs/evidence/aggressive-car-models-2026-11-07/settings-"+RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var directory: String = "user://racing_settings_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.call("_show_screen","settings")
	await settle()
	var page: SettingsPage = app.root_ui.find_child("SettingsPage",true,false)
	page._show_section("graphics")
	await settle()
	var toggle: CheckButton=page.find_child("SimpleCarModels",true,false)
	check(toggle!=null and not toggle.button_pressed,"stronger model selector defaults off")
	var saved: Dictionary=app.records.settings.duplicate(true)
	toggle.set_pressed(true)
	check(page.draft_simple_models and page.dirty and app.records.settings==saved,"model selection stages without changing saved preferences")
	page._show_section("audio");page._show_section("graphics")
	check(page.draft_simple_models and (page.find_child("SimpleCarModels",true,false) as CheckButton).button_pressed,"model draft survives section changes")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size = dimensions
		await settle()
		var models: CheckButton=page.find_child("SimpleCarModels",true,false)
		page.content_scroll.ensure_control_visible(models)
		await settle()
		check(models!=null and page.content_scroll.get_global_rect().encloses(models.get_global_rect()),"model option fits at "+str(dimensions))
		root.get_texture().get_image().save_png(output.path_join("graphics-"+str(dimensions.x)+".png"))
	var original_path: String=app.records.path
	app.records.path=directory.path_join("missing/records.json")
	check(not page._apply() and page.draft_simple_models and not app.records.settings.get("reduced_car_models",false),"failed model Apply preserves committed choice and retryable draft")
	app.records.path=original_path
	app.records.settings.simple_car_models=true
	check(page._apply(),"ordinary graphics Apply remains available")
	var reopened := LocalRecords.new(app.records.path)
	reopened.load_records()
	check(reopened.settings.simple_car_models and reopened.settings.reduced_car_models,"new selection persists independently of the retired preference")
	page._reset()
	check(not page.draft_simple_models and app.records.settings.reduced_car_models,"Reset stages the standard models until Apply")
	check(page._apply() and not app.records.settings.reduced_car_models,"Reset saves the standard model choice")
	app.call("_show_screen","garage")
	await settle()
	var garage: GaragePage = app.root_ui.find_child("GaragePage",true,false)
	check(not garage.showroom.car.simple_model,"Garage uses the optimised standard despite a legacy preference")
	var track: NativeTrack = NativeTrack.read("res://tests/fixtures/legacy_tracks/slicks_arto4_test.json")
	var bounds: Array[AABB] = []
	for enabled: bool in [false,true]:
		app.records.settings.reduced_car_models = enabled
		var game: Node = load("res://core/game.tscn").instantiate()
		game.initial_track = track
		game.preference_records = app.records
		game.production_mode = true
		game.attempt_practice = true
		game.hitch_diagnostics_enabled = false
		game.vehicle_id = "compact"
		root.add_child(game)
		game.paused = true
		game.set_physics_process(false)
		while game.car==null or not game.car.model_ready:await process_frame
		check(game.car.simple_model==enabled,"race uses the selected optional model "+str(enabled))
		bounds.append(game.car_weathering.bounds)
		var snapshot: Array = game.sim.state.snapshot()
		game.call("_process",0.0)
		check(snapshot == game.sim.state.snapshot(),"render option leaves canonical state unchanged")
		check(game.track_session.target_laps == RaceRules.LAPS,"ordinary race retains five laps")
		game.queue_free()
		await process_frame
	check(bounds[0].is_equal_approx(bounds[1]),"wash volume mapping retains detailed bounds")
	app.queue_free()
	await process_frame
	print("RACING_SETTINGS_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
