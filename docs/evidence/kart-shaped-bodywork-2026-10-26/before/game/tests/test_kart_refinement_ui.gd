extends SceneTree
## Actual Garage and race integration with disposable local data.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/kart-refinement-2026-10-25/native"
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func settle(frames: int = 12) -> void:
	for tick: int in range(frames):
		await process_frame
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless": check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"native capture "+label)
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence-root="): output = argument.trim_prefix("--evidence-root=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280,720)
	if "--bake-art" in OS.get_cmdline_user_args():
		var showroom := CarShowroom.new()
		showroom.vehicle_id = "kart"
		showroom.livery = VehicleLivery.defaults("kart")
		showroom.read_only = true
		showroom.size = Vector2(1280,720)
		root.add_child(showroom)
		await settle(20)
		check(showroom.showroom_viewport.get_texture().get_image().save_png("res://assets/menu/kart_illustration_v1.png") == OK,"refreshed native catalogue artwork")
		showroom.free()
	else:
		var directory: String = ProjectSettings.globalize_path("res://../build/kart-refinement/local/"+TrackLibrary.unique_id())
		DirAccess.make_dir_recursive_absolute(directory)
		var app: Node = load("res://core/app.tscn").instantiate()
		app.records = LocalRecords.new(directory.path_join("records.json"))
		app.records.settings.selected_car = "kart"
		app.library = TrackLibrary.new(directory)
		app.cloud_root_override = directory.path_join("cloud")
		root.add_child(app)
		while not app.startup_complete: await process_frame
		VehicleCatalog.selected = "kart"
		app._show_screen("garage")
		await settle()
		var page: GaragePage = app.root_ui.find_child("GaragePage",true,false)
		check(page != null,"actual Garage loads")
		page.open_car(VehicleCatalog.IDS.find("kart"))
		await settle(30)
		check(page.showroom.car.vehicle_id == "kart","Garage uses production kart")
		for dimensions: Vector2i in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1600,720)]:
			root.size = dimensions
			await settle(20)
			check(root.get_visible_rect().encloses(page.showroom.get_global_rect()),"Garage fits "+str(dimensions))
			await capture("garage-"+str(dimensions.x))
		root.size = Vector2i(1280,720)
		var track: NativeTrack = NativeTrack.read("res://resources/tracks/ellipse.json")
		await app._start_race(track,true,true)
		await settle(20)
		var game: Node = app.game
		game.set_physics_process(false)
		game.countdown_label.hide()
		check(game.handling.vehicle_id == "kart" and game.car.vehicle_id == "kart","actual race keeps kart mesh and handling")
		check(game.handling.snapshot() == VehicleCatalog.config("kart").snapshot(),"actual race uses the current complete kart tune")
		check(game.car.front_wheels.size() == 2 and game.car.rolling_wheels.size() == 4,"actual race wheel articulation")
		check(game.trails.wheelbase == game.handling.wheelbase,"canonical tyre trails retained")
		await capture("race")
		game.camera.current = false
		game.hud.hide()
		var camera := Camera3D.new()
		game.get_node("World").add_child(camera)
		camera.current = true
		camera.fov = 32
		for side: float in [-1.0,1.0]:
			camera.position = game.car.position+Vector3(side*2.7,1.6,3.8)
			camera.look_at(game.car.position+Vector3(0,0.4,0))
			await settle()
			await capture("race-seat-rear-"+str(side))
		app._leave_race()
		app.queue_free()
		await settle(5)
	FileAccess.open(output+"/report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("KART_REFINEMENT_UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
