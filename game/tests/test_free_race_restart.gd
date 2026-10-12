extends SceneTree
## Actual pause-menu input and race reset; fictional tickets and isolated storage.
const Client = preload("res://backend/backend_client.gd")
const App = preload("res://core/app.gd")
const Account = preload("res://backend/account_controller.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0
var capture_directory: String = ""

class RestartApp extends App:
	func _ready() -> void: pass

class RestartAccount extends Account:
	func _ready() -> void: pass

class TicketClient extends Client:
	var document: Dictionary
	var tickets: int = 0
	var fail_ticket: bool = false
	func race_ticket(_version: String, vehicle: String, _key: String, _purpose: String = "race") -> Dictionary:
		tickets += 1
		await get_tree().create_timer(0.03).timeout
		if fail_ticket: return {"ok":false,"status":503,"error":"Race service unavailable","data":{}}
		return {"ok":true,"status":201,"error":"","data":{"ticket_id":"restart-fixture-%d" % tickets,"manifest":TrackLifecycle._contract(document,vehicle)}}
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		return {"ok":true,"status":200,"error":"","data":{"free":1,"balance":0,"ad_preview_available":true,"ads_available":false,"purchases_available":false}}

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)

func run() -> void:
	root.size = Vector2i(1280,720)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-restart="): capture_directory = argument.trim_prefix("--capture-restart=")
	var folder: String = ProjectSettings.globalize_path("res://../build/free-race-restart-" + TrackLibrary.unique_id())
	DirAccess.make_dir_recursive_absolute(folder)
	var client := TicketClient.new()
	client.document = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	var account := RestartAccount.new()
	account.client.free()
	account.client = client
	account.add_child(client)
	var app := RestartApp.new()
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.online = account
	app.add_child(account)
	app.root_ui = Control.new()
	app.add_child(app.root_ui)
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	app.cloud = cloud
	app.add_child(cloud)
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.lifecycle = TrackLifecycle.new()
	app.lifecycle.cloud = cloud
	app.lifecycle.library = app.library
	app.add_child(app.lifecycle)
	root.add_child(app)
	client.configure("http://127.0.0.1:18181")
	app.selected_track = TrackCompiler.compile(client.document)
	app.selected_track.metadata.cloud_version = "restart-fixture-version"
	VehicleCatalog.selected = "compact"
	await app._start_race(app.selected_track,false,true)
	var game: Node = app.game
	check(game != null and bool(game.get_meta("race_offline_only",false)),"The actual offline start preserves its restart policy")
	game.set_physics_process(false)
	game.countdown_ticks = 0
	game.sim.state.tick = 120
	game.sim.state.position += Vector2(2,4)
	game.toggle_pause()
	await frames()
	await tap_restart(game)
	check(not game.paused and not game.hud.pause_menu.visible and game.hud.touch.enabled,"Guest pause Restart closes the drawer and restores controls")
	check(game.sim.state.tick == 0 and game.countdown_ticks == 360 and game.track_session.target_laps == 5,"Guest restart resets timing with a fresh five-lap countdown")
	for tick: int in range(370): game._physics_process(1.0/120.0)
	check(game.countdown_ticks == 0 and game.sim.state.tick == 10,"Restarted race advances past the countdown into active timing")
	client._access_token = "fictional-access"
	client.player = {"id":"restart-fixture-player"}
	# Explicitly accepted offline races must remain restartable without the service.
	client.fail_ticket = true
	game.countdown_ticks = 0
	game.sim.state.tick = 180
	game.toggle_pause()
	await frames()
	await tap_restart(game)
	while app.cloud_starting: await process_frame
	check(client.tickets == 0,"An explicitly offline Free Race restart makes no ticket request")
	check(not game.paused and game.sim.state.tick == 0 and game.countdown_ticks == 360,"Signed-in offline Restart resets immediately while the service is unavailable")
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog: child.queue_free()
	await process_frame
	# Recover independently so a broken offline case cannot hide online coverage.
	if game.paused: game.toggle_pause()
	game.set_meta("race_offline_only",false)
	client.fail_ticket = false
	client.tickets = 0
	app.cloud_ticket = {"ticket_id":"original-ticket"}
	game.countdown_ticks = 0
	game.sim.state.tick = 240
	game.toggle_pause()
	await frames()
	await tap_restart(game)
	while app.cloud_starting: await process_frame
	check(client.tickets == 1 and app.cloud_ticket.get("ticket_id","") == "restart-fixture-1","Signed-in pause Restart obtains a fresh server ticket")
	check(not game.paused and not game.hud.pause_menu.visible and game.sim.state.tick == 0 and game.countdown_ticks == 360,"Verified restart closes pause and resets the car and countdown")
	await capture("restarted")
	client.fail_ticket = true
	game.countdown_ticks = 0
	game.sim.state.tick = 360
	game.toggle_pause()
	await frames()
	await tap_restart(game)
	while app.cloud_starting: await process_frame
	check(game.paused and game.sim.state.tick == 360 and app.cloud_ticket.get("ticket_id","") == "restart-fixture-1","Ticket failure preserves the paused attempt and its ticket")
	var notice: AcceptDialog
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog: notice = child
	check(notice != null and notice.visible,"Restart failure is visible above the hidden menu root")
	check(notice is ConfirmationDialog and notice.get_ok_button().text == "Race offline","Failed verified Free Race offers an explicit offline retry")
	await capture("restart-error")
	if notice is ConfirmationDialog:
		notice.canceled.emit()
		await frames()
		check(game.paused and game.sim.state.tick == 360 and app.cloud_ticket.get("ticket_id","") == "restart-fixture-1","Canceling offline retry preserves the current attempt")
		await app._retry_race()
		for child: Node in app.root_ui.get_children():
			if child is ConfirmationDialog: notice = child
		# A response must never restart a replacement game after navigation.
		app.game = null
		notice.confirmed.emit()
		await frames()
		check(game.paused and game.sim.state.tick == 360,"A stale offline confirmation cannot restart a game after navigation")
		app.game = game
		await app._retry_race()
		for child: Node in app.root_ui.get_children():
			if child is ConfirmationDialog: notice = child
		var tickets_before: int = client.tickets
		notice.confirmed.emit()
		await frames()
		check(not game.paused and game.sim.state.tick == 0 and game.countdown_ticks == 360,"Accepting offline retry closes pause and starts a fresh countdown")
		check(app.cloud_ticket.is_empty() and game.resume_ticket_id.is_empty() and bool(game.get_meta("race_offline_only",false)),"Offline retry clears competitive and resume tickets and remembers the offline choice")
		check(client.tickets == tickets_before,"Offline retry does not repeat the unavailable server request")
		await capture("offline-restarted")
		game.countdown_ticks = 0
		game.sim.state.tick = 480
		game.toggle_pause()
		await frames()
		await tap_restart(game)
		check(not game.paused and game.sim.state.tick == 0 and client.tickets == tickets_before,"Subsequent offline restarts remain free of server requests")
	app.free()
	await process_frame
	print("FREE_RACE_RESTART: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func frames() -> void:
	for index: int in range(4): await process_frame

func tap_restart(game: Node) -> void:
	var button: Button = game.hud.pause_menu.find_child("Restart",true,false)
	if DisplayServer.get_name() == "headless":
		button.pressed.emit()
	else:
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.position = button.get_global_rect().get_center()
		down.pressed = true
		Input.parse_input_event(down)
		await process_frame
		var up: InputEventMouseButton = down.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
	await frames()

func capture(label: String) -> void:
	if capture_directory.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(capture_directory)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(capture_directory.path_join(label+".png")) == OK,"restart evidence saved: " + label)
