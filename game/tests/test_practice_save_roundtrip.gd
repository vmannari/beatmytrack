extends "res://tests/test_practice_save_recovery.gd"
## Exercise failure/return through the full App, retained editor and production Game.

func drive_lap() -> void:
	var game: Node = app.game
	game.set_process(false)
	game.set_physics_process(false)
	var driver := RouteDriver.new()
	for tick: int in range(24000):
		var frame: DriveFrame = driver.sample(game.sim.state,game.native_track,game.handling)
		game.driver.clear()
		game.driver.set_touch(0,&"steer_right" if frame.steer>=0 else &"steer_left",absf(float(frame.steer))/127.0)
		game.driver.set_touch(1,&"accelerate",float(frame.throttle)/255.0)
		game.driver.set_touch(2,&"brake",float(frame.brake)/255.0)
		game._physics_process(1.0/120)
		if game.practice_validation.finished: break
	check(game.practice_validation.finished,"full App completes an actual ordered creator-test lap")

func run() -> void:
	create_timer(180).timeout.connect(func() -> void: print("FAIL: recovery round trip deadline"); quit(1))
	root.size = Vector2i(1280,720)
	OS.set_environment("BMT_API_URL","")
	folder = ProjectSettings.globalize_path("res://../build/storm-test-recovery-2026-10-26/roundtrip-"+str(OS.get_process_id()))
	storage = ReceiptStorage.new(folder.path_join("tracks"))
	app = preload("res://core/app.tscn").instantiate()
	app.library = storage
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	check(app.library==storage and app.lifecycle.library==storage,"full App uses only isolated receipt storage")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	app.document = fixture.document.duplicate(true)
	app.document.id = "recovery_roundtrip"
	app.document.creator = "Guest"
	check(storage.save_document(app.document)==OK,"full App fixture is saved before testing")
	app._show_screen("create")
	while not is_instance_valid(app.canvas) or app.canvas.native_preview==null or app.test_button.disabled or app.editor_world._building:
		await process_frame
	var editor: Node = app.root_ui
	var canvas: Node = app.canvas
	var world: Node = app.editor_world
	await app._test_document()
	check(is_instance_valid(app.game) and app.game.preparation_complete,"ordinary Test action opens the production practice scene")
	check(app.root_ui==editor and editor.process_mode==Node.PROCESS_MODE_DISABLED,"practice retains and suspends the actual editor")
	var document: Dictionary = app.document.duplicate(true)
	await drive_lap()
	await settle()
	var dialog: AcceptDialog = current_dialog()
	check(dialog!=null and dialog.can_process(),"failed receipt opens a working modal on the actual retained editor")
	if dialog!=null:
		await click(dialog,dialog.return_button,true)
		check(app.game==null and app.screen=="create" and editor.visible and editor.can_process(),"native touch Return restores the actual editor and releases practice")
		check(app.root_ui==editor and app.canvas==canvas and app.editor_world==world,"return preserves the exact editor, canvas and world instances")
		check(app.document==document and canvas.document==document,"return preserves the exact editable document")
		check(not app.lifecycle.status_for(document).is_empty() and not storage.is_tested(document),"return keeps the staged recording without fabricating a test receipt")
		check(app.records.records.is_empty(),"test and recovery never create a scored personal best")
	# The invalid-recording boundary must offer a fresh lap rather than an endless retry.
	await app._test_document()
	await drive_lap()
	app.game.race_proof.overflow = true
	await settle()
	dialog = current_dialog()
	check(dialog!=null and dialog.confirm_button.text=="Restart","an incomplete recording offers Restart with an explicit return action")
	if dialog!=null:
		var old_witness: TrackSession = app.game.practice_validation
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER; enter.pressed = true
		dialog.push_input(enter,true)
		await settle()
		check(app.game.practice_validation!=old_witness and not app.game.practice_validation.finished and not app.game.paused,"native Restart begins a fresh untimed attempt")
		check(app._draft_test_save_context.is_empty() and current_dialog()==null,"Restart clears the failed attempt and modal")
		app._leave_race()
		await settle()
		check(app.game==null and app.root_ui==editor and editor.can_process(),"restarted test can leave through the ordinary return flow")
	app.free()
	await settle()
	print("PRACTICE_SAVE_ROUNDTRIP: %d checks, %d failures" % [checks,failures])
	var file := FileAccess.open(OUTPUT+"/roundtrip-"+("headless" if DisplayServer.get_name()=="headless" else RenderingServer.get_current_rendering_method())+"-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t")); file.close()
	quit(1 if failures else 0)
