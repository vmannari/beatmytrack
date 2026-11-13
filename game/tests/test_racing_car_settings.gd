extends SceneTree
## SMO01-SMO03: actual Settings, retained Garage and races ignore retired preferences.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/simple-models-only-2026-11-08/settings-headless"
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("MODEL_SETTINGS_FAIL ",label)
func settle() -> void:
	for _frame: int in range(8): await process_frame
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output=" ): output=argument.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var directory: String = "user://racing_settings_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.records.settings={"music_enabled":false,"simple_car_models":false,"reduced_car_models":false}
	check(app.records.save_records()==OK,"private legacy-false fixture saves")
	app.library = TrackLibrary.new(directory)
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("settings")
	await settle()
	var page: SettingsPage = app.root_ui.find_child("SettingsPage",true,false)
	page._show_section("graphics")
	check(page.find_child("SimpleCarModels",true,false)==null,"main Settings omits model selector")
	var committed: Dictionary=app.records.settings.duplicate(true)
	page._reset()
	check(app.records.settings==committed,"ordinary Graphics reset remains staged")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
		root.size=dimensions
		await settle()
		check(page.find_child("SimpleCarModels",true,false)==null,"removed selector stays absent at "+str(dimensions))
		for field: String in ["shadow_quality","render_resolution","anti_aliasing"]:
			check(page.find_child("GraphicsChoice_"+field,true,false)!=null,"ordinary graphics choice remains "+field)
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(output.path_join("graphics-"+str(dimensions.x)+".png"))==OK,"capture actual Graphics page")
	check(page._apply(),"ordinary Graphics Apply saves")
	var reopened:=LocalRecords.new(app.records.path)
	reopened.load_records()
	check(reopened.settings.get("reduced_car_models")==false and reopened.settings.get("simple_car_models")==false,"legacy false fields remain compatible")
	app._show_screen("garage")
	await settle()
	var garage: GaragePage=app._retained_garage
	while not garage.showroom.showroom_ready: await process_frame
	check(garage.showroom.car.simple_model,"actual Garage uses reduced geometry with legacy fields false")
	var track: NativeTrack=NativeTrack.read("res://resources/tracks/ellipse.json")
	var bounds: Array[AABB]=[]
	for preference: Variant in [null,false,true]:
		if preference==null:
			app.records.settings.erase("reduced_car_models");app.records.settings.erase("simple_car_models")
		else:
			app.records.settings.reduced_car_models=preference;app.records.settings.simple_car_models=preference
		var game: Node=load("res://core/game.tscn").instantiate()
		game.initial_track=track;game.preference_records=app.records
		game.production_mode=true;game.attempt_practice=true;game.hitch_diagnostics_enabled=false
		root.add_child(game)
		game.paused=true;game.set_physics_process(false)
		while game.car==null or not game.car.model_ready: await process_frame
		check(game.car.simple_model,"race always uses reduced geometry "+str(preference))
		bounds.append(game.car_weathering.bounds)
		var snapshot: Array=game.sim.state.snapshot()
		game._process(0.0)
		check(snapshot==game.sim.state.snapshot(),"rendering preserves canonical state")
		check(game.track_session.target_laps==RaceRules.LAPS,"ordinary race retains five laps")
		var pause_page:=SettingsPage.new()
		pause_page.records=app.records;pause_page.race_context=true
		root.add_child(pause_page);pause_page._show_section("graphics")
		check(pause_page.find_child("SimpleCarModels",true,false)==null,"pause Settings omits model selector")
		pause_page._reset();check(pause_page._apply() and game.car.simple_model,"pause Reset/Apply retains reduced car")
		pause_page.free();game.free();await process_frame
	check(bounds[0]==bounds[1] and bounds[1]==bounds[2],"retired preferences cannot change wash mapping")
	app.queue_free();await settle()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("RACING_SETTINGS_TESTS ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
