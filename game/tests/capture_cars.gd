extends SceneTree
## Actual graphical integration/captures, isolated from owner saves.
var checks: int = 0
var failures: int = 0
var output: String = "res://../docs/evidence/cars"

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func settle() -> void:
	for i: int in range(6): await process_frame
	await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"saved " + label)

func _run() -> void:
	if "--car=kart" in OS.get_cmdline_user_args(): output = "res://../docs/evidence/kart"
	output = ProjectSettings.globalize_path(output)
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280,720)
	var directory: String = "user://cars_capture_" + TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var app: Node = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.library = TrackLibrary.new(directory)
	root.add_child(app)
	await settle()
	for index: int in range(VehicleCatalog.IDS.size()):
		if "--car=kart" in OS.get_cmdline_user_args() and VehicleCatalog.IDS[index] != "kart": continue
		app.call("_show_screen","garage")
		var selector: OptionButton = app.root_ui.find_child("VehicleSelector",true,false)
		check(selector != null,"garage exposes car selector")
		selector.item_selected.emit(index)
		await settle()
		var id: String = VehicleCatalog.IDS[index]
		check(VehicleCatalog.selected == id,"selector selects " + id)
		for size_value: Vector2i in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1600,720)]:
			root.size = size_value
			await settle()
			var bounds: Rect2 = app.root_ui.get_global_rect()
			var current: OptionButton = app.root_ui.find_child("VehicleSelector",true,false)
			check(bounds.encloses(current.get_global_rect()),id+" selector stays within viewport")
			var navigation: Button = app.root_ui.find_child("Tab_garage",true,false)
			check(bounds.encloses(navigation.get_global_rect()),id+" bottom navigation stays within viewport")
			await capture(id+"-garage-"+str(size_value.x))
		root.size = Vector2i(1280,720)
		app.call("_show_screen","play")
		await capture(id+"-home")
		var home_nav: Button = app.root_ui.find_child("Tab_play",true,false)
		check(app.root_ui.get_global_rect().encloses(home_nav.get_global_rect()),id+" Home navigation stays within viewport")
		app.call("_start_race",app.selected_track,false)
		await settle()
		var game: Node = app.game
		game.set_physics_process(false)
		check(game.handling.vehicle_id == id and game.car.vehicle_id == id,id+" race uses chosen handling and mesh")
		check(game.trails.wheelbase == game.handling.wheelbase,id+" trails follow wheelbase")
		check(game.hud.handling_button.visible == (id == "compact"),id+" preset selector cannot replace car identity")
		game.countdown_label.hide()
		await capture(id+"-gameplay")
		# Detail view of the actual runtime asset using a separate evidence camera.
		game.camera.current = false
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 7.4
		game.get_node("World").add_child(camera)
		camera.position = game.car.position + Vector3(-5,4,-7)
		camera.look_at(game.car.position+Vector3(0,0.5,0))
		camera.current = true
		game.hud.hide()
		await capture(id+"-model")
		var wheel_state := VehicleState.new()
		game.set_process(false)
		var wheel_origin := Vector2(game.car.position.x,-game.car.position.z)
		game.car.present(wheel_origin,0.0,wheel_state,DriveFrame.new())
		camera.position = game.car.position + Vector3(-5,4,-7)
		camera.look_at(game.car.position+Vector3(0,0.5,0))
		await capture(id+"-wheel-phase-a")
		wheel_state.tick = 1
		game.car.present(wheel_origin+Vector2(0,0.12),0.0,wheel_state,DriveFrame.new())
		camera.position = game.car.position + Vector3(-5,4,-7)
		camera.look_at(game.car.position+Vector3(0,0.5,0))
		await capture(id+"-wheel-phase-b")
		game.set_process(true)
		if id == "kart":
			# Diagnostic overhead view makes cockpit and nose alignment reviewable.
			camera.size = 3.8
			camera.position = game.car.position + Vector3(0,8,0.001)
			camera.look_at(game.car.position)
			await capture("kart-model-overhead")
		app.call("_leave_race")
		await settle()
		if id in ["formula","kart"]: await capture(id+"-tracks")
		# Result fixture checks record partition, vehicle label and retry identity.
		app.call("_start_race",app.selected_track,false)
		await settle()
		game = app.game
		game.set_physics_process(false)
		game.attempt_practice = false
		var result_laps: Array[float] = [20.0,20.0,20.0,20.0,20.0]
		game.track_session.lap_times = result_laps
		game.track_session.completed_laps = 5
		game.track_session.lap_start_time = 100.0
		game.track_session.finished = true
		app.call("_results")
		await settle()
		if id in ["formula","kart"]: await capture(id+"-results-fixture")
		check(app.records.best_for(app.selected_track,game.handling) == 100.0,id+" result saves under selected car")
		app.call("_retry_race")
		await settle()
		check(app.game.handling.vehicle_id == id and app.game.car.vehicle_id == id,id+" result retry preserves vehicle")
		app.call("_leave_race")
		await settle()
		# Practice uses same selected vehicle and remains untimed.
		app.call("_start_race",app.selected_track,true)
		await settle()
		check(app.game.editor_test and app.game.handling.vehicle_id == id,id+" creator practice keeps selected car")
		app.returning_to_editor = false
		app.call("_leave_race")
		await settle()
	var records_path: String = app.records.path
	app.queue_free()
	await process_frame
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(records_path+suffix): DirAccess.remove_absolute(records_path+suffix)
	DirAccess.remove_absolute(directory)
	VehicleCatalog.selected = "compact"
	print("CAR_CAPTURE_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
