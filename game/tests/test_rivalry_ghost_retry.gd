extends "res://tests/test_rivalry_start_failure.gd"
## Controlled delayed transport, real adapter, App start and retry presentation.
const Adapter = preload("res://backend/weekly_rivalry_client.gd")

class GhostClient extends "res://backend/backend_client.gd":
	signal released
	var requests: int = 0
	var held: bool = false
	var fail: bool = false
	var issued: Dictionary
	var recording: Dictionary = {"ticks":12000,"poses":[[0,8,8,0,0,0,0],[12000,12,12,0,0,0,0]]}
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _authenticated: bool = false) -> Dictionary:
		if path.ends_with("/tickets"): return {"ok":true,"data":issued.duplicate(true)}
		requests += 1
		if held: await released
		else: await get_tree().process_frame
		return {"ok":not fail,"data":{"run_id":"ghost-run","recording":recording}}

class QuietRivalry extends Adapter:
	func refresh(_force: bool = true) -> void: pass
	func poll_result() -> void: pass

func fetch(done: Dictionary) -> void:
	done.recording = await app._rivalry_ghost(0,0,true)
	done.finished = true

func begin_race(done: Dictionary) -> void:
	await app._start_rivalry_race(0,0)
	done.finished = true

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	evidence = "res://../docs/evidence/rivalry-ghost-retry-2026-10-18/ui"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--evidence="): evidence = argument.trim_prefix("--evidence=")
	root.size = Vector2i(1280,720)
	var folder: String = "user://rivalry_ghost_retry_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.records.settings.ghost_mode = "off"
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app.records.settings.ghost_mode = "off"
	app.online.client._access_token = "isolated-fixture"
	app.online.client.player = {"id":"fixture-self"}
	var cloud := CloudFixture.new()
	cloud.client = app.online.client
	cloud.root_override = folder.path_join("cloud")
	app.add_child(cloud)
	app.cloud = cloud
	var client := GhostClient.new()
	client.configure("http://fixture.invalid")
	client.player = {"id":"fixture-self"}
	app.add_child(client)
	var rivalry := QuietRivalry.new()
	rivalry.client = client
	app.add_child(rivalry)
	app.rivalry = rivalry
	var doc: Dictionary = TrackDocument.create_default()
	var body: String = JSON.stringify(doc)
	var metadata: Dictionary = {"name":"Ghost retry fixture","creator":"Beat my track","theme":doc.theme,"track_id":"ghost-track","version_id":"ghost-version","content_hash":body.sha256_text(),"points":doc.points}
	var entry: Dictionary = cloud.entry_from_metadata(metadata)
	DirAccess.make_dir_recursive_absolute(str(entry.cache_path).get_base_dir())
	var file := FileAccess.open(str(entry.cache_path),FileAccess.WRITE)
	file.store_string(body)
	file.close()
	var track: NativeTrack = Cloud.compile_entry(entry)
	for pose: Array in client.recording.poses:
		pose[1] = track.spawn.x+6.0
		pose[2] = track.spawn.y+3.0
	client.issued = {"ticket_id":"ghost-ticket","manifest":manifest(track)}
	rivalry.model = WeeklyRivalry.new(true)
	for slot: int in range(rivalry.model.tracks.size()):
		var rows: Array[Dictionary] = rivalry.model.board(slot)
		for row: Dictionary in rows:
			row.driver_id = str(row.id)
			row.run_id = "ghost-run"
		rivalry.model.tracks[slot].entries = rows
	rivalry.model.sample = false
	rivalry.model.status = "active"
	rivalry.model.tracks[0].entry = metadata
	rivalry.snapshot_scope = rivalry.scope()
	app.rivalry_section = "detail"
	app._show_screen("rivalry")
	var saved_rows: Array = rivalry.model.tracks[0].entries.duplicate(true)
	for row: Dictionary in rivalry.model.tracks[0].entries: row.ms = null
	app._rivalry()
	var page: WeeklyRivalryPage = app.root_ui.find_child("WeeklyRivalryPage",true,false)
	check(page.ghost_choice == 0 and (await app._rivalry_ghost(0,0,true)).is_empty() and client.requests == 0,"an empty field shows no ghost and preserves automatic targeting")
	rivalry.model.tracks[0].entries = saved_rows
	app._rivalry()
	page = app.root_ui.find_child("WeeklyRivalryPage",true,false)
	check(page.ghost_choice == 0 and not rivalry.model.ghost_target(0,page.ghost_choice).is_empty(),"later verified standings restore the same automatic ghost policy")
	client.held = true
	check(app._rivalry_ghost(0,0).is_empty() and client.requests == 1,"cold ghost prefetch returns immediately and starts one request")
	var first: Dictionary = {"finished":false}
	var second: Dictionary = {"finished":false}
	fetch(first)
	fetch(second)
	await process_frame
	check(not first.finished and not second.finished and client.requests == 1,"race callers wait for the same in-flight ghost instead of observing an empty cache")
	client.released.emit()
	while not first.finished or not second.finished: await process_frame
	check(first.recording == client.recording and second.recording == client.recording and client.requests == 1,"coalesced waiters receive the completed validated recording")
	check(await app._rivalry_ghost(0,0,true) == client.recording and client.requests == 1,"warm ghost reuses the immutable cached run")
	check((await app._rivalry_ghost(0,3,true)).is_empty() and client.requests == 1,"explicit no-ghost choice never requests a recording")
	# A race that reaches Loading ghost before transport completes must wait.
	rivalry._ghost_cache.clear()
	var start: Dictionary = {"finished":false}
	begin_race(start)
	while client.requests < 2: await process_frame
	for frame: int in range(12): await process_frame
	check(not start.finished and app.game == null,"cold real Rivalry start waits for its selected ghost")
	client.released.emit()
	while not start.finished: await process_frame
	check(app.game != null and app.rivalry_racing and app.game.ghost_bests.get("race",{}) == client.recording,"real Rivalry start installs the cold selected recording")
	app.game.set_physics_process(false)
	app.game.set_process(false)
	app.game.countdown_ticks = 0
	app.game.race_cues.reset()
	app.game._present_personal_ghost(1.0)
	check(app.game.personal_ghost.mesh != null and app.game.personal_ghost.visible,"cold recording has a visible mesh even when personal ghosts are disabled")
	await capture("cold-ghost")
	# Reproduce a retry after a previous attempt had no ghost or local PB mesh.
	app.game.personal_ghost.mesh = null
	app.game.ghost_bests = {}
	app.game.ghost_mode = "off"
	app.game.personal_ghost.hide()
	client.held = false
	client.issued.ticket_id = "retry-ticket"
	await app._retry_race()
	check(app.cloud_ticket.get("ticket_id","") == "retry-ticket" and app.rivalry.result_ticket == "retry-ticket" and app.rivalry_racing,"retry keeps a fresh Rivalry ticket and its result-poll identity")
	check(app.game.ghost_bests.get("race",{}) == client.recording and app.game.personal_ghost.mesh != null,"retry builds a missing mesh after installing the external ghost")
	app.game.countdown_ticks = 0
	app.game.race_cues.reset()
	app.game._present_personal_ghost(1.0)
	check(app.game.personal_ghost.visible,"retry actually displays its chosen ghost")
	await capture("retry-ghost")
	check(app.records.settings.ghost_mode == "off","Rivalry presentation leaves the saved personal-ghost preference unchanged")
	rivalry._ghost_cache.clear()
	client.fail = true
	check((await app._rivalry_ghost(0,0,true)).is_empty() and rivalry._ghost_pending.is_empty(),"unavailable ghost completes without a stuck pending request")
	client.fail = false
	check(await app._rivalry_ghost(0,0,true) == client.recording,"failed optional download can recover on the next attempt")
	rivalry._ghost_cache.clear()
	client.held = true
	var stale: Dictionary = {"finished":false}
	fetch(stale)
	await process_frame
	client.player = {"id":"replacement-account"}
	client.released.emit()
	while not stale.finished: await process_frame
	check(stale.recording.is_empty() and rivalry._ghost_cache.is_empty(),"account change discards an in-flight recording")
	app.queue_free()
	await process_frame
	print("RIVALRY_GHOST_RETRY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
