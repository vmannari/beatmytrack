extends "res://tests/test_runtime_render_lifecycle.gd"
## Interrupt the real Garage graphics stage using the retained lifecycle checks.
func run() -> void:
	create_timer(100).timeout.connect(func() -> void: print("FAIL: Garage graphics cancellation deadline"); quit(1))
	if DisplayServer.get_name() == "headless": quit(1); return
	var folder: String = "user://garage-render-lifecycle-"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.records.settings.music_enabled = false
	process_frame.connect(observe)
	for action: String in ["navigation","car","selection","scope","teardown"]:
		mode = action
		interrupted = false
		Staging.warmed.clear()
		VehicleCatalog.selected = "electric"
		app.online.client.configure("")
		app._show_screen("garage")
		app._start_garage_free_drive()
		while is_instance_valid(app) and (not interrupted or is_instance_valid(app.game) or is_instance_valid(app.race_loading)):
			await process_frame
		for _frame: int in range(8): await process_frame
		check(interrupted,action+" interrupts actual Garage staged drawing")
		if action == "teardown":
			check(not is_instance_valid(app),"App teardown retires Garage graphics")
		else:
			check(app.game == null and not is_instance_valid(app.race_loading) and not app.cloud_starting,action+" cannot activate abandoned Garage graphics")
			check(app.root_ui.visible,action+" restores visible menu")
			check(app.find_children("ParkingHallDrive","Node",true,false).is_empty(),action+" leaves no abandoned hall")
	process_frame.disconnect(observe)
	print("GARAGE_TEST_DRIVE_CANCELLATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
