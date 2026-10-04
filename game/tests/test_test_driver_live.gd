extends SceneTree
## Explicit loopback acceptance of the operator-created developer test field.
## Uses isolated client storage; never submits a human PB or changes membership.
var checks: int = 0
var failures: int = 0
var app: Node

func _initialize() -> void:
	call_deferred("run")
	root.ready.connect(func() -> void:
		create_timer(120.0).timeout.connect(func() -> void:
			print("FAIL: live test-driver acceptance deadline")
			quit(1)))

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	if OS.get_environment("BMT_API_URL") != "http://127.0.0.1:18181" or OS.get_environment("BMT_DEV_AUTH_KEY").is_empty():
		print("Set the explicit local API and private development key before this live check")
		quit(1)
		return
	var folder: String = "user://test_driver_live_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	await app.online.sign_in_developer()
	check(app.online.client.signed_in(),"developer authenticates against the live local service")
	check(app.online.capabilities.get("test_drivers",false),"live bootstrap advertises test drivers")
	app.rivalry.set_test_population(true)
	await app.rivalry.refresh()
	check(app.rivalry.model.status == "active" and app.rivalry.model.test_population,"live weekly test membership loads")
	check(app.rivalry.model.tracks.size() == 5 and app.rivalry.model.standing().size() == 14,"live field has five tracks and fourteen drivers")
	if app.rivalry.model.tracks.size() != 5:
		quit(1)
		return
	var test_count: int = 0
	for driver: Dictionary in app.rivalry.model.standing():
		if driver.get("is_test_driver",false): test_count += 1
	check(test_count == 13,"thirteen rivals carry explicit test identity markers")
	var ghost_slot: int = -1
	var ghost_driver: String = ""
	for slot: int in range(5):
		for row: Dictionary in app.rivalry.model.tracks[slot].entries:
			if row.get("is_test_driver",false) and float(row.ms) > 0.0:
				ghost_slot = slot
				ghost_driver = str(row.id)
				break
		if ghost_slot >= 0: break
	check(ghost_slot >= 0,"at least one test rival has a verified five-lap finish")
	if ghost_slot >= 0:
		var recording: Dictionary = await app.rivalry.ghost(ghost_slot,ghost_driver)
		check(not recording.is_empty() and not recording.has("replay"),"client downloads a verified rival's derived ghost")
		check(not PersonalGhostRun.sample(recording,0.0).is_empty(),"downloaded ghost begins at the real start")
		check(PersonalGhostRun.sample(recording,float(recording.get("ticks",0))+1.0).is_empty(),"downloaded ghost ends without extrapolation")
	var evidence: String = OS.get_environment("BMT_CAPTURE_CLOUD")
	if not evidence.is_empty(): DirAccess.make_dir_recursive_absolute(evidence)
	app._show_screen("rivalry")
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		for section: String in ["overview","tracks","detail","standings"]:
			app.rivalry_section = section
			app.rivalry_track = ghost_slot if ghost_slot >= 0 else 0
			app._rivalry()
			for _frame: int in range(8): await process_frame
			var notice: Label = app.root_ui.find_child("RivalryDataNotice",true,false)
			check(notice != null and notice.text.begins_with("TEST RIVALRY"),"live menu clearly identifies its test field")
			if not evidence.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(evidence.path_join("live-%s-%dx%d.png" % [section,dimensions.x,dimensions.y])) == OK,"live screenshot saves")
	var ticket: Dictionary = await app.rivalry.ticket(0)
	check(not ticket.is_empty(),"human can request a real race ticket for the test field")
	await app.online.client.logout()
	app.queue_free()
	await process_frame
	print("TEST_DRIVER_LIVE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
