extends "res://tests/test_rivalry_start_failure.gd"
## Exercise the actual detail button through viewport mouse/touch dispatch.

class DelayedClient extends "res://backend/backend_client.gd":
	signal released
	var issued: Dictionary
	var snapshot: Dictionary
	var hold_appearance: bool = false
	var hold_current: bool = false
	func test_drivers_available() -> bool: return false
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if path == "/rivalry/appearance" and hold_appearance: await released
		if path.begins_with("/rivalry/current") and hold_current: await released
		if path.ends_with("/tickets"): return {"ok":true,"data":issued.duplicate(true)}
		return {"ok":true,"data":snapshot.duplicate(true)}

class CountingRivalry extends "res://backend/weekly_rivalry_client.gd":
	var tickets: int = 0
	var activation_refreshes: int = 0
	func refresh(_force: bool = true) -> void: activation_refreshes += 1
	func refresh_now() -> void: await super.refresh(true)
	func poll_result() -> void: pass
	func ticket(slot: int) -> Dictionary:
		tickets += 1
		return await super.ticket(slot)

func click(button: Button, touch: bool) -> void:
	var location: Vector2 = button.get_global_rect().get_center()
	for down: bool in [true,false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.index = 4
			event.position = location
			event.pressed = down
			root.push_input(event,true)
		else:
			var event := InputEventMouseButton.new()
			event.position = location
			event.button_index = MOUSE_BUTTON_LEFT
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			event.pressed = down
			root.push_input(event,true)
		await process_frame

func finish_refresh(client: DelayedClient) -> void:
	client.hold_appearance = false
	client.hold_current = false
	client.released.emit()

func wait_for_start() -> void:
	var deadline: int = Time.get_ticks_msec()+15000
	while Time.get_ticks_msec() < deadline and (app.cloud_starting or is_instance_valid(app.race_loading)):
		await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.size = Vector2i(1280,720)
	evidence = "res://../docs/evidence/rivalry-one-click-2026-10-18/ui"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	var folder: String = "user://rivalry_one_click_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var cloud := CloudFixture.new()
	cloud.client = app.online.client
	cloud.root_override = folder.path_join("cloud")
	app.add_child(cloud)
	app.cloud = cloud
	var client := DelayedClient.new()
	client.configure("http://fixture.invalid")
	client._access_token = "isolated-fixture"
	client.player = {"id":"you"}
	app.add_child(client)
	var rivalry := CountingRivalry.new()
	rivalry.client = client
	rivalry.appearance_provider = app.rivalry.appearance_provider
	app.add_child(rivalry)
	app.rivalry = rivalry
	rivalry.changed.connect(app._rivalry_changed)
	app.online.client._access_token = "isolated-fixture"
	app.online.client.player = {"id":"you"}
	var doc: Dictionary = TrackDocument.create_default()
	var body: String = JSON.stringify(doc)
	var metadata: Dictionary = {"name":"One click fixture","creator":"Beat my track","theme":doc.theme,"track_id":"one-click-track","version_id":"one-click-version","content_hash":body.sha256_text(),"points":doc.points}
	var entry: Dictionary = cloud.entry_from_metadata(metadata)
	DirAccess.make_dir_recursive_absolute(str(entry.cache_path).get_base_dir())
	var file := FileAccess.open(str(entry.cache_path),FileAccess.WRITE)
	file.store_string(body)
	file.close()
	var track: NativeTrack = Cloud.compile_entry(entry)
	client.issued = {"ticket_id":"one-click-ticket","manifest":manifest(track)}
	var sample := WeeklyRivalry.new(true)
	client.snapshot = {"state":"active","group_id":"fixture-group","self_id":"you","week":sample.week,"server_now":0,"ends_at":604800,"vehicle_id":"compact","standings":sample.standing(),"tracks":[]}
	for slot: int in range(sample.tracks.size()):
		client.snapshot.tracks.append({"board_id":"board_"+str(slot),"entry":metadata.duplicate(true),"entries":sample.board(slot)})
	rivalry.model.apply_snapshot(client.snapshot)
	rivalry.snapshot_scope = rivalry.scope()
	app.rivalry_section = "detail"
	app.rivalry_track = 0
	app.rivalry_ghost_choice = 3
	var snapshot: Dictionary = client.snapshot.duplicate(true)
	for scenario: String in ["mouse","touch","refresh-mouse","refresh-touch","current-mouse","current-touch"]:
		var touch: bool = scenario.ends_with("touch")
		app.rivalry_section = "detail"
		app._show_screen("rivalry")
		for frame: int in range(8): await process_frame
		app._finish_menu_page_slide()
		var button: Button = app.content.find_child("RivalryStartRace",true,false)
		check(button != null and not button.disabled,"Race button is ready before the first input")
		if button == null: continue
		var refreshing: bool = scenario.begins_with("refresh") or scenario.begins_with("current")
		if refreshing:
			# Real refresh waits for appearance sync before _fetch emits changed.
			client.hold_appearance = scenario.begins_with("refresh")
			client.hold_current = scenario.begins_with("current")
			rivalry._synced_appearance = ""
			rivalry.refresh_now()
			check(rivalry.busy and not button.disabled,"background refresh reaches the enabled-button window")
		var before: int = rivalry.tickets
		await click(button,touch)
		if refreshing:
			check(app.cloud_starting and is_instance_valid(app.race_loading) and app.game == null and rivalry.tickets == before,"first input visibly waits for the in-flight refresh: "+scenario)
			await capture("waiting-"+scenario)
			# Repeated activation cannot issue another authorization while waiting.
			app._start_rivalry_race(0,3)
			var refreshes: int = rivalry.activation_refreshes
			app._activate_menu_page(app._navigation_generation)
			app.rivalry_refresh_ticks = 59
			for child: Node in app.get_children():
				if child is Timer and is_equal_approx(child.wait_time,0.5): child.timeout.emit()
			check(rivalry.activation_refreshes == refreshes,"covered race preparation does not start another background refresh")
			finish_refresh(client)
		await wait_for_start()
		check(rivalry.tickets == before+1,"one input requests exactly one Rivalry ticket: "+scenario)
		check(app.game != null and app.rivalry_racing,"one input starts the Rivalry race: "+scenario)
		if app.game != null:
			check(app.game.track_session.target_laps == 5,"one-click start retains five competitive laps")
			await capture("started-"+scenario)
			app._leave_race()
	# A queued tap retains the exact identity that was visible when pressed.
	for scenario: String in ["group","version","unavailable","navigation","account","deadline"]:
		client.snapshot = snapshot.duplicate(true)
		rivalry.model.apply_snapshot(client.snapshot)
		rivalry.snapshot_scope = rivalry.scope()
		app.rivalry_section = "detail"
		app._show_screen("rivalry")
		for frame: int in range(8): await process_frame
		app._finish_menu_page_slide()
		client.hold_current = true
		rivalry.refresh_now()
		var button: Button = app.content.find_child("RivalryStartRace",true,false)
		var before: int = rivalry.tickets
		await click(button,false)
		check(app.cloud_starting and rivalry.tickets == before,"cancellation fixture waits before ticket authorization: "+scenario)
		match scenario:
			"group": client.snapshot.group_id = "next-group"
			"version": client.snapshot.tracks[0].entry.version_id = "next-version"
			"unavailable": client.snapshot.tracks[0].available = false
			"navigation": app._show_screen("garage")
			"account": client.player = {"id":"other-account"}
			"deadline": app.race_loading.get_node("RaceLoadingDeadline").timeout.emit()
		finish_refresh(client)
		await wait_for_start()
		check(rivalry.tickets == before and app.game == null and app.race_loading == null and not app.cloud_starting,"stale queued tap never authorizes a hidden or different race: "+scenario)
		if scenario in ["group","version","unavailable","deadline"]:
			check(notice() != null,"changed Rivalry or deadline gives actionable feedback: "+scenario)
		else:
			check(notice() == null,"deliberate navigation/account change stays quiet: "+scenario)
		if notice() != null:
			notice().queue_free()
			await process_frame
		client.player = {"id":"you"}
		rivalry.reset()
	app.queue_free()
	await process_frame
	print("RIVALRY_ONE_CLICK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
