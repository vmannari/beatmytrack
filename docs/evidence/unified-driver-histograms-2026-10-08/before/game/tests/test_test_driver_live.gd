extends SceneTree
## Explicit HTTPS/loopback acceptance of the operator-created test field.
## Uses isolated client storage and automatic backend-created development membership.
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
	var api: String = OS.get_environment("BMT_API_URL")
	if not (api == "http://127.0.0.1:18181" or api.begins_with("https://")) or OS.get_environment("BMT_DEV_AUTH_KEY").is_empty():
		print("Set an explicit HTTPS/loopback test API and private development key before this live check")
		quit(1)
		return
	var folder: String = "user://test_driver_live_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var subject: String = OS.get_environment("BMT_TEST_SUBJECT")
	if subject.is_empty() or subject == "developer":
		await app.online.sign_in_developer()
	else:
		var client: Node = app.online.client
		client._remember(await client._send("/auth/development",HTTPClient.METHOD_POST,{"subject":subject,"display_name":subject},false,"",PackedStringArray(["X-Dev-Auth-Key: "+OS.get_environment("BMT_DEV_AUTH_KEY")])))
	check(app.online.client.signed_in(),"developer authenticates against the live local service")
	check(app.online.capabilities.get("test_drivers",false),"live bootstrap advertises test drivers")
	await app.rivalry.refresh()
	check(app.rivalry.model.status == "active" and app.rivalry.model.test_population,"live weekly test membership loads")
	check(app.rivalry.model.tracks.size() == 5 and app.rivalry.model.standing().size() >= 14 and app.rivalry.model.standing().size() <= 20,"live automatic field has five tracks and fourteen to twenty drivers")
	if app.rivalry.model.tracks.size() != 5:
		quit(1)
		return
	var test_count: int = 0
	for driver: Dictionary in app.rivalry.model.standing():
		if driver.get("is_test_driver",false): test_count += 1
	check(test_count >= 13 and test_count <= 19,"automatic rivals carry explicit test identity markers")
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
			check(notice == null and app.rivalry.model.test_population,"clean menu retains backend population isolation without debug footer")
			if section in ["overview","standings"]:
				var player_row: Control = app.root_ui.find_child("Driver_you",true,false)
				var scroll: Control = app.root_ui.find_child("RivalryStandingsScroll",true,false)
				check(scroll.get_global_rect().grow(1).encloses(player_row.get_global_rect()),"actual unranked player stays visible in the table")
			if not evidence.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(evidence.path_join("live-%s-%dx%d.png" % [section,dimensions.x,dimensions.y])) == OK,"live screenshot saves")
	var ticket: Dictionary = await app.rivalry.ticket(0)
	check(not ticket.is_empty(),"human can request a real race ticket for the test field")
	if OS.has_environment("BMT_TEST_HISTOGRAM"):
		var histogram: Dictionary = await app.online.client.request_api("/dev/test-drivers/track-versions/"+OS.get_environment("BMT_TEST_HISTOGRAM")+"/histogram?vehicle_id=compact",HTTPClient.METHOD_GET,{},"",true)
		check(histogram.ok and histogram.data.get("test_population",false),"private cloud histogram identifies simulated test data")
		check(histogram.ok and int(histogram.data.get("population",0)) > 0,"private cloud histogram contains actually verified PBs")
		await app.cloud.refresh(true)
		for _page: int in range(5):
			if app.cloud.next_cursor.is_empty(): break
			await app.cloud.refresh(true)
		app._show_screen("tracks")
		var browser: TrackBrowser = app.root_ui.find_child("TrackBrowser",true,false)
		while browser.loading: await process_frame
		for metadata: Dictionary in app.cloud.entries:
			if str(metadata.get("version_id","")) == OS.get_environment("BMT_TEST_HISTOGRAM"):
				browser._select(app.cloud.entry_from_metadata(metadata))
				while browser.selecting: await process_frame
				break
		check(browser.selected_track != null and browser.selected_track.metadata.has("cloud_version"),"cloud histogram track is playable")
		if browser.selected_track != null and browser.selected_track.metadata.has("cloud_version"):
			await browser._load_cloud_detail(browser.selected_track)
			var key: String = app.records.key_for(browser.selected_track,HandlingSelection.config())
			var snapshot: Dictionary = browser.discovery.records_by_rules_key.get(key,{})
			check(int(snapshot.get("test_population",0)) > 0,"Race displays the labeled test histogram without inventing a public rank")
			check(browser.find_child("TestHistogramToggle",true,false) != null,"development Race can switch back to the real player histogram")
			browser.test_histograms = false
			await browser._load_cloud_detail(browser.selected_track)
			check(not browser.discovery.records_by_rules_key[key].has("test_population"),"real player histogram never inherits simulated data")
			browser.test_histograms = true
			await browser._load_cloud_detail(browser.selected_track)
			for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
				root.size = dimensions
				for _frame: int in range(8): await process_frame
				if not evidence.is_empty() and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					check(root.get_texture().get_image().save_png(evidence.path_join("live-histogram-%dx%d.png" % [dimensions.x,dimensions.y])) == OK,"labeled live histogram screenshot saves")
	await app.online.client.logout()
	app.queue_free()
	await process_frame
	print("TEST_DRIVER_LIVE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
