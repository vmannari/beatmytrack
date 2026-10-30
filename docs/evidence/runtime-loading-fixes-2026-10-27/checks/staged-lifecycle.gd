extends SceneTree
const Staging = preload("res://race/world_render_preparation.gd")
var app: Node
var checks: int = 0
var failures: int = 0
var mode: String = ""
var interrupted: bool = false
var done: bool = false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func observe() -> void:
	if interrupted or not is_instance_valid(app) or not is_instance_valid(app.game) or not is_instance_valid(app.race_loading): return
	if mode in ["model","details","batch"]:
		if app.game.car != null and not app.game.car.model_ready and (mode=="model" or (mode=="details" and app.game.car._model_stage=="details") or (mode=="batch" and app.game.car._model_stage.contains("batches"))):
			interrupted = true
			app._show_screen("settings")
		return
	if app.race_loading.status_label.text != "Preparing graphics...": return
	var preparation: Node = app.game.world_render_preparation
	if preparation == null or preparation.pending.is_empty(): return
	interrupted = true
	match mode:
		"navigation": app._show_screen("settings")
		"car": VehicleCatalog.selected = "kart"
		"selection": app.selected_track = NativeTrack.new()
		"scope": app.online.client.configure("http://127.0.0.1:1")
		"teardown": app.queue_free()
func run() -> void:
	var task_config:=ConfigFile.new()
	task_config.set_value("backend","url","")
	assert(task_config.save("user://backend.cfg")==OK)
	OS.unset_environment("BMT_API_URL")

	create_timer(120).timeout.connect(func() -> void: print("FAIL: rendering lifecycle deadline"); quit(1))
	if DisplayServer.get_name() == "headless": quit(1); return
	var folder: String = "user://render-lifecycle-"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json")); app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records.settings.music_enabled = false
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var track: NativeTrack = TrackCompiler.compile(TrackDocument.create_default())
	track.metadata.cloud_version = "owned-render-lifecycle-fixture"
	process_frame.connect(observe)
	for action: String in ["model","details","batch","navigation","car","selection","scope","teardown"]:
		mode = action; interrupted = false; done = false
		Staging.warmed.clear()
		preload("res://vehicle/prepared_car_cache.gd").entries.clear()
		VehicleCatalog.selected = "compact"; app.online.client.configure("")
		app._show_screen("tracks"); app.selected_track = track
		app._start_race(track,false,true)
		while is_instance_valid(app) and (not interrupted or is_instance_valid(app.game) or is_instance_valid(app.race_loading)): await process_frame
		for _frame: int in range(8): await process_frame
		check(interrupted,action+" interrupts actual native staged drawing")
		if action == "teardown": check(not is_instance_valid(app),"App teardown retires rendering work")
		else: check(app.game == null and not is_instance_valid(app.race_loading) and not app.cloud_starting,action+" cannot attach or activate abandoned graphics")
	process_frame.disconnect(observe)
	print("RUNTIME_RENDER_LIFECYCLE: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
