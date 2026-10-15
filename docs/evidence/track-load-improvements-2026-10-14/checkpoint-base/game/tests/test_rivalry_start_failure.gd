extends SceneTree
## Full Rivalry -> prepared track -> ticket contract path; isolated, no live writes.
var app: Node
var checks: int = 0
var failures: int = 0
var evidence: String = "res://../docs/evidence/rivalry-start-feedback-2026-10-11"
const Cloud = preload("res://backend/cloud_tracks.gd")

class RivalryFixture extends "res://backend/weekly_rivalry_client.gd":
	signal released
	var issued: Dictionary = {}
	var held: bool = false
	var requested: bool = false
	func _ready() -> void: pass
	func refresh(_force: bool = true) -> void: pass
	func poll_result() -> void: pass
	func ticket(_slot: int) -> Dictionary:
		requested = true
		if held: await released
		else: await get_tree().process_frame
		return issued.duplicate(true)

class CloudFixture extends "res://backend/cloud_tracks.gd":
	var download_ok: bool = true
	func _ready() -> void: pass
	func flush_outbox() -> void: pass
	func download(_entry: Dictionary) -> bool:
		await get_tree().process_frame
		if not download_ok: last_error = "Track download failed. Check your connection and try again."
		return download_ok

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",message)

func notice() -> AcceptDialog:
	for child: Node in app.root_ui.get_children():
		if child is AcceptDialog: return child
	return null

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence))
	root.get_texture().get_image().save_png(evidence.path_join(name+".png"))

func manifest(track: NativeTrack) -> Dictionary:
	var engine: Dictionary = Engine.get_version_info()
	var version: String = "%s.%s.%s.%s.%s.%s" % [engine.major,engine.minor,engine.patch,engine.status,engine.build,str(engine.hash).left(9)]
	var config: HandlingConfig = VehicleCatalog.config("compact")
	var values: Dictionary = {}
	for property: Dictionary in config.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: values[str(property.name)] = config.get(str(property.name))
	return {"track_content_hash":track.content_hash,"engine_version":version,"tick_rate":VehicleSimulation.TICK_RATE,"track_schema":TrackDocument.SCHEMA,"replay_schema":"bmt-replay-v1","verifier_version":"canonical-verifier-1","physics_version":VehicleSimulation.PHYSICS_VERSION,"compiler_version":TrackCompiler.VERSION,"rules_key":RaceRules.KEY,"config_hash":JSON.stringify(values,"",true).sha256_text()}

func start_late(done: Dictionary) -> void:
	await app._start_rivalry_race(0,3)
	done.finished = true

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	VehicleCatalog.selected = "compact"
	root.size = Vector2i(1280,720)
	var folder: String = "user://rivalry_start_failure_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder)
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	var original_cloud: Node = app.cloud
	var original_rivalry: Node = app.rivalry
	var cloud := CloudFixture.new()
	cloud.client = app.online.client
	cloud.root_override = folder.path_join("cloud")
	app.add_child(cloud)
	app.cloud = cloud
	var rivalry := RivalryFixture.new()
	rivalry.client = app.online.client
	app.add_child(rivalry)
	app.rivalry = rivalry
	rivalry.changed.connect(app._rivalry_changed)
	app.online.client._access_token = "isolated-rivalry-fixture"
	app.online.client.player = {"id":"fixture-self"}
	var doc: Dictionary = TrackDocument.create_default()
	doc.name = "Dust Cloud"
	doc.theme = "desert"
	var body: String = JSON.stringify(doc)
	var metadata: Dictionary = {"name":"Dust Cloud","creator":"Beat my track","theme":"desert","track_id":"fixture-dust-cloud","version_id":"fixture-dust-cloud-version","content_hash":body.sha256_text(),"points":doc.points}
	var entry: Dictionary = cloud.entry_from_metadata(metadata)
	DirAccess.make_dir_recursive_absolute(str(entry.cache_path).get_base_dir())
	var file := FileAccess.open(str(entry.cache_path),FileAccess.WRITE)
	file.store_string(body)
	file.close()
	var track: NativeTrack = Cloud.compile_entry(entry)
	check(track != null,"Dust Cloud document compiles in the isolated published-track cache")
	for scenario: String in ["older-server","newer-server","unknown-server","track-mismatch","ticket-failure","download-failure","compile-failure"]:
		rivalry.model = WeeklyRivalry.new(true)
		rivalry.model.server_standings = rivalry.model.standing()
		for slot: int in range(rivalry.model.tracks.size()):
			rivalry.model.tracks[slot].entries = rivalry.model.board(slot)
		rivalry.model.sample = false
		rivalry.model.tracks[0].name = "Dust Cloud"
		rivalry.model.tracks[0].theme = "desert"
		rivalry.model.tracks[0].entry = metadata.duplicate(true)
		rivalry.model.tracks[0].document = doc
		rivalry.snapshot_scope = rivalry.scope()
		rivalry.error = ""
		cloud.last_error = ""
		cloud.download_ok = scenario != "download-failure"
		rivalry.issued = {"ticket_id":"fixture-ticket","manifest":manifest(track)}
		match scenario:
			"older-server":
				rivalry.issued.manifest.compiler_version = "creator-compiler-22"
				rivalry.issued.manifest.track_content_hash = "0".repeat(64)
			"newer-server": rivalry.issued.manifest.compiler_version = "creator-compiler-24"
			"unknown-server": rivalry.issued.manifest.compiler_version = "creator-compiler-unknown"
			"track-mismatch": rivalry.issued.manifest.track_content_hash = "0".repeat(64)
			"ticket-failure": rivalry.issued = {}
			"compile-failure": rivalry.model.tracks[0].entry.content_hash = "1".repeat(64)
		app.rivalry_section = "detail"
		app.rivalry_track = 0
		app._show_screen("rivalry")
		await app._start_rivalry_race(0,3)
		await process_frame
		check(app.game == null and app.race_loading == null and not app.cloud_starting and app.cloud_ticket.is_empty(),"failed Rivalry start leaves no active race/ticket or blocked loading: "+scenario)
		var dialog: AcceptDialog = notice()
		check(dialog != null and not dialog.dialog_text.is_empty(),"failed Rivalry start produces a prominent owned alert: "+scenario)
		if dialog != null:
			if scenario == "older-server":
				check(dialog.dialog_text.contains("server update"),"old-server compiler mismatch explains the actual required update before checking the track hash")
			elif scenario == "newer-server":
				check(dialog.dialog_text.contains("Update the game"),"newer-server compiler mismatch gives the appropriate client action")
			elif scenario == "unknown-server":
				check(dialog.dialog_text.begins_with("The game and server versions do not match."),"unrecognized compiler format does not invent which side is older")
			elif scenario == "track-mismatch":
				check(dialog.dialog_text == "Track differs from the server's race contract.","matching compiler still rejects an incompatible track contract")
			# A normal background refresh must not erase an action's failure dialog.
			rivalry.error = ""
			rivalry.changed.emit()
			await process_frame
			check(is_instance_valid(dialog) and dialog.visible,"background refresh preserves the start-failure alert: "+scenario)
			await capture(scenario)
			if scenario == "older-server":
				root.size = Vector2i(960,540)
				dialog.popup_centered()
				await capture("older-server-960")
				# Embedded windows use logical viewport coordinates under stretch.
				check(root.get_visible_rect().encloses(Rect2(Vector2(dialog.position),Vector2(dialog.size))),"full server-update alert fits a compact desktop viewport")
				root.size = Vector2i(1280,720)
			dialog.queue_free()
			await process_frame
	cloud.download_ok = true
	rivalry.model.tracks[0].entry = metadata.duplicate(true)
	rivalry.issued = {"ticket_id":"fixture-valid-ticket","manifest":manifest(track)}
	await app._start_rivalry_race(0,3)
	check(app.game != null and app.rivalry_racing and app.game.track_session.target_laps == 5 and app.cloud_ticket.ticket_id == "fixture-valid-ticket","matching Rivalry contract still starts five verified laps without an optional ghost")
	if app.game != null: app._leave_race()
	rivalry.held = true
	rivalry.requested = false
	var done: Dictionary = {"finished":false}
	start_late(done)
	while not rivalry.requested: await process_frame
	app._show_screen("garage")
	rivalry.released.emit()
	while not done.finished: await process_frame
	check(app.screen == "garage" and app.game == null and notice() == null,"late ticket after deliberate navigation cannot display a stale alert or start a hidden race")
	app.online.client._access_token = ""
	app.online.client.player = {}
	app.cloud = original_cloud
	app.rivalry = original_rivalry
	app.queue_free()
	await process_frame
	print("RIVALRY_START_FAILURE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
