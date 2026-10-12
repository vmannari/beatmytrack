extends SceneTree
## Actual start coroutine, held transport and rendered feedback; no live writes.
var checks: int = 0
var failures: int = 0
var app: Node
var evidence: String = "res://../docs/evidence/race-start-feedback-2026-10-11"

class HeldTicket extends "res://backend/cloud_tracks.gd":
	signal released
	var requested: bool = false
	func ticket(_track: NativeTrack, _creator: bool = false, _vehicle: String = "", _handling: HandlingConfig = null, _issued: Dictionary = {}) -> Dictionary:
		requested = true
		last_error = ""
		await released
		return {}
	func flush_outbox() -> void: pass

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func dialog() -> AcceptDialog:
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog: return child
	return null

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	root.size = Vector2i(1280,720)
	var folder: String = "user://race_start_feedback_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._show_screen("tracks")
	await app._start_race(null,false)
	check(dialog() != null and dialog().dialog_text == "Choose a track before starting a race.","missing selection explains the required action")
	dialog().queue_free()
	await process_frame
	var original: Node = app.cloud
	var track := NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.cloud_version = "isolated-feedback"
	var held := HeldTicket.new()
	held.client = original.client
	held.root_override = original.root_override
	app.add_child(held)
	app.cloud = held
	for scenario: String in ["car","track","account","navigation","empty-error"]:
		app._show_screen("tracks")
		app.selected_track = track
		VehicleCatalog.selected = "compact"
		app.online.client._access_token = "isolated-feedback"
		app.online.client.player = {"id":"isolated-feedback"}
		held.requested = false
		app._start_race(track,false)
		while not held.requested: await process_frame
		var overlay: Node = app.race_loading
		app._start_race(track,false)
		check(app.race_loading == overlay and dialog() == null,"duplicate start keeps one visible preparation: "+scenario)
		match scenario:
			"car": VehicleCatalog.selected = "kart"
			"track": app.selected_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
			"account": app.online.client.player = {"id":"changed-feedback"}
			"navigation": app._show_screen("garage")
		held.released.emit()
		await process_frame
		check(not app.cloud_starting and app.race_loading == null and app.game == null,"failed start releases preparation and creates no hidden race: "+scenario)
		var notice: AcceptDialog = dialog()
		if scenario == "navigation":
			check(notice == null,"intentional navigation has no stale error")
		elif scenario == "empty-error":
			check(notice is ConfirmationDialog and notice.dialog_text.begins_with("Could not connect the race.") and notice.ok_button_text == "Race offline","empty ticket error gives a reason and preserves offline racing")
			await capture("connection-failure")
		else:
			check(notice != null and notice.dialog_text.begins_with(scenario.capitalize()+" changed"),"start explains the changed prerequisite: "+scenario)
			if scenario == "car": await capture("car-changed")
		if notice != null: notice.queue_free()
		await process_frame
	app.cloud = original
	app.online.client._access_token = ""
	app.online.client.player = {}
	held.queue_free()
	VehicleCatalog.selected = "compact"
	app.selected_track = track
	app._show_screen("tracks")
	await app._start_race(track,false,true)
	check(app.game != null and app.game.track_session.target_laps == 5 and app.race_loading == null,"offline five-lap start succeeds after feedback recovery")
	if app.game != null: app._leave_race()
	var model := WeeklyRivalry.new(true)
	app.rivalry.model = model
	app.rivalry_section = "detail"
	app.rivalry_track = 0
	for state: String in ["busy","completed","unavailable","failed-refresh"]:
		model.completed = state == "completed"
		model.tracks[0].available = state != "unavailable"
		app.rivalry.busy = state in ["busy","failed-refresh"]
		app.rivalry.error = "Refresh Rivalry and try again." if state == "failed-refresh" else ""
		app._show_screen("rivalry")
		var button: Button = app.root_ui.find_child("RivalryStartRace",true,false)
		var caption: String = {"busy":"UPDATING RIVALRY...","completed":"WEEK COMPLETE","unavailable":"TRACK UNAVAILABLE","failed-refresh":"RIVALRY UNAVAILABLE"}[state]
		check(button != null and button.disabled and button.text == caption,"disabled Rivalry race explains its actual blocker: "+state)
		await capture("rivalry-"+state)
	app.rivalry.busy = false
	app.queue_free()
	await process_frame
	print("RACE_START_FEEDBACK: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
