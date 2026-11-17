extends SceneTree
## Deterministic held-ticket tests; no network, player data or external writes.
const Selected = preload("res://race/selected_track_preparation.gd")
const Saved = preload("res://track/road_cache_bakes.gd")
const Roads = preload("res://editor/road_preparation.gd")
var checks: int = 0
var failures: int = 0
var app: Node

class HeldRoad extends RefCounted:
	var done: bool = false
	var aborted: bool = false
	var result: Variant
	func cancel() -> void: aborted = true

class TestApp extends "res://core/app.gd":
	var started_roads: Array = []
	var use_real_road: bool = false
	func _start_race_road_job(track: NativeTrack) -> RefCounted:
		var job: RefCounted = super._start_race_road_job(track) if use_real_road else HeldRoad.new()
		started_roads.append(job)
		return job

class HeldCloud extends "res://backend/cloud_tracks.gd":
	signal release_ticket
	var entered: int = 0
	var reply: Dictionary = {}
	func ticket(_track: NativeTrack, _creator_test: bool = false, _vehicle_id: String = "", _attempt_handling: HandlingConfig = null, _issued: Dictionary = {}, _purpose: String = "race") -> Dictionary:
		entered += 1
		await release_ticket
		return reply.duplicate(true)

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)

func launch(track: NativeTrack, finished: Dictionary) -> void:
	await app._start_race(track,false)
	finished.done = true

func wait_ticket(cloud: HeldCloud, target: int) -> void:
	while cloud.entered < target: await process_frame

func dismiss_dialogs() -> void:
	for dialog: Node in app.root_ui.find_children("*","AcceptDialog",true,false): dialog.queue_free()
	await process_frame

func run() -> void:
	OS.set_environment("BMT_API_URL", "")
	var folder: String = "user://race-road-overlap-"+TrackLibrary.unique_id()
	app = TestApp.new()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	app._garage_preloader.evict()
	app.online.client.player = {"id":"fixture-player"}
	app.online.client._access_token = "fixture-access"
	var cloud := HeldCloud.new()
	cloud.client = app.online.client
	app.add_child(cloud)
	app.cloud = cloud
	app._show_screen("tracks")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/star_spline_lap.json"))
	var track: NativeTrack = TrackCompiler.compile(document)
	track.metadata.cloud_version = "fixture-version"
	app.selected_track = track
	check(NativeTrackVisual.race_roads_need_preparation(track),"fixture requires road preparation")
	var finished: Dictionary = {"done":false}
	launch(track,finished)
	await wait_ticket(cloud,1)
	check(app.started_roads.size() == 1 and not app.started_roads[0].done,"road preparation starts before the ticket reply")
	var first: HeldRoad = app.started_roads[0]
	app._close_race_loading()
	check(first.aborted,"closing loading cancels the in-flight road job immediately")
	cloud.release_ticket.emit()
	while not finished.done: await process_frame
	check(app.game == null and not app.cloud_starting,"late ticket cannot start a cancelled race")
	# Retry before the cancelled job has actually retired: neither speculative
	# preparation nor fallback may overlap its still-running CPU work.
	var retry: Dictionary = {"done":false}
	launch(track,retry)
	await wait_ticket(cloud,2)
	check(app.started_roads.size() == 1,"a fast retry does not start a speculative worker before cleanup")
	cloud.reply = {"ticket_id":"fixture-ticket"}
	cloud.release_ticket.emit()
	for frame: int in range(5): await process_frame
	check(app.started_roads.size() == 1 and not retry.done and app.game == null,"fallback waits for the cancelled worker to retire")
	app._close_race_loading()
	while not retry.done: await process_frame
	check(app.started_roads.size() == 1 and app.game == null,"navigation cancels the cleanup wait without starting another worker")
	first.done = true
	first.result = {}
	await process_frame
	Selected.reap_discarded()
	check(Selected.ready_for_job(),"cancelled worker is reaped")
	finished = {"done":false}
	launch(track,finished)
	await wait_ticket(cloud,3)
	var second: HeldRoad = app.started_roads[-1]
	cloud.reply = {}
	cloud.release_ticket.emit()
	while not finished.done: await process_frame
	check(second.aborted and app.game == null and not app.cloud_starting,"ticket failure cancels road work and does not start a race")
	await dismiss_dialogs()
	second.done = true
	second.result = {}
	await process_frame
	Selected.reap_discarded()
	check(Selected.ready_for_job(),"failed-ticket worker is reaped")
	finished = {"done":false}
	launch(track,finished)
	await wait_ticket(cloud,4)
	var third: HeldRoad = app.started_roads[-1]
	cloud.reply = {"ticket_id":"fixture-ticket"}
	cloud.release_ticket.emit()
	for frame: int in range(5): await process_frame
	check(not finished.done and app.game == null and app.cloud_starting,"successful ticket waits for the already-started road job")
	app._close_race_loading()
	while not finished.done: await process_frame
	check(third.aborted and app.game == null,"navigation during road wait cancels the claimed worker")
	third.done = true
	third.result = {}
	await process_frame
	Selected.reap_discarded()
	finished = {"done":false}
	launch(track,finished)
	await wait_ticket(cloud,5)
	var stale: HeldRoad = app.started_roads[-1]
	var original_vehicle: String = VehicleCatalog.selected
	VehicleCatalog.selected = "pickup" if original_vehicle != "pickup" else "compact"
	cloud.reply = {"ticket_id":"fixture-ticket"}
	cloud.release_ticket.emit()
	while not finished.done: await process_frame
	check(stale.aborted and app.game == null and not app.cloud_starting,"vehicle changes discard the ticket and cancel stale road work")
	VehicleCatalog.selected = original_vehicle
	stale.done = true
	stale.result = {}
	await process_frame
	Selected.reap_discarded()
	await dismiss_dialogs()
	# A save-time bake for this exact track is shared; an unrelated save is
	# not allowed to impose an extra wait after a ticket has been issued.
	var save_job := HeldRoad.new()
	Saved.job = save_job
	Saved.active_key = Roads.disk_key_for(track)
	finished = {"done":false}
	launch(track,finished)
	await wait_ticket(cloud,6)
	var existing_jobs: int = app.started_roads.size()
	cloud.reply = {"ticket_id":"fixture-ticket"}
	cloud.release_ticket.emit()
	for frame: int in range(5): await process_frame
	check(app.started_roads.size() == existing_jobs and not finished.done,"matching save bake prevents a duplicate race builder")
	app._close_race_loading()
	while not finished.done: await process_frame
	check(not save_job.aborted and app.game == null,"cancelled race leaves the independent saved bake untouched")
	var unrelated := NativeTrack.new()
	unrelated.content_hash = "unrelated-fixture"
	Saved.active_key = Roads.disk_key_for(unrelated)
	finished = {"done":false}
	launch(track,finished)
	await wait_ticket(cloud,7)
	cloud.release_ticket.emit()
	for frame: int in range(5): await process_frame
	check(app.started_roads.size() == existing_jobs+1 and not finished.done,"unrelated save does not delay fallback road preparation")
	var unrelated_race_job: HeldRoad = app.started_roads[-1]
	app._close_race_loading()
	while not finished.done: await process_frame
	check(unrelated_race_job.aborted and not save_job.aborted,"closing the race cancels its own worker only")
	unrelated_race_job.done = true
	unrelated_race_job.result = {}
	Saved.job = null
	Saved.active_key = []
	await process_frame
	Selected.reap_discarded()
	# Hold a real ticket while the actual CPU worker finishes. Its private
	# staged artifact must be discarded when the ticket fails.
	document.pieces[0].width = float(document.pieces[0].width)+0.5
	for index: int in range(document.pieces[0].point_widths.size()): document.pieces[0].point_widths[index] = document.pieces[0].width
	var real_track: NativeTrack = TrackCompiler.compile(document)
	real_track.metadata.cloud_version = "second-fixture-version"
	app.selected_track = real_track
	preload("res://track/road_mesh_disk_cache.gd").directory = folder.path_join("roads")
	var save_key: Array = Roads.disk_key_for(real_track)
	Saved.start(real_track,self)
	check(Saved.baking_key(save_key),"actual save job exposes its immutable race disk identity")
	var save_deadline: int = Time.get_ticks_msec()+60000
	while Saved.job != null and Time.get_ticks_msec() < save_deadline: await process_frame
	var saved_packet: Dictionary = preload("res://track/road_mesh_disk_cache.gd").read_arrays(save_key,Roads.key_for(real_track))
	check(Saved.job == null and not Saved.baking_key(save_key) and not saved_packet.is_empty(),"completed save clears its identity and publishes valid reusable arrays")
	app.use_real_road = true
	finished = {"done":false}
	launch(real_track,finished)
	await wait_ticket(cloud,8)
	var real_job: RefCounted = app.started_roads[-1]
	var deadline: int = Time.get_ticks_msec()+60000
	while not real_job.done and Time.get_ticks_msec() < deadline: await process_frame
	check(real_job.done and not finished.done,"real road preparation completes while the ticket remains held")
	var receipt: Dictionary = real_job.result.get("receipt",{}) if real_job.result is Dictionary else {}
	var staged: String = str(receipt.get("path",""))
	check(not staged.is_empty() and FileAccess.file_exists(staged),"real worker stages a private artifact without publishing it")
	cloud.reply = {}
	cloud.release_ticket.emit()
	while not finished.done: await process_frame
	check(not staged.is_empty() and not FileAccess.file_exists(staged) and app.game == null,"ticket failure discards the completed staged artifact")
	await dismiss_dialogs()
	app.use_real_road = false
	app.selected_track = track
	finished = {"done":false}
	launch(track,finished)
	await wait_ticket(cloud,9)
	var fourth: HeldRoad = app.started_roads[-1]
	fourth.result = {}
	fourth.done = true
	cloud.reply = {"ticket_id":"fixture-ticket"}
	cloud.release_ticket.emit()
	while not finished.done: await process_frame
	check(is_instance_valid(app.game) and not fourth.aborted and app.started_roads.size() == 7,"completed overlapped work starts the race without a duplicate road job")
	if is_instance_valid(app.game):
		app.game.set_process(false)
		app.game.set_physics_process(false)
		app._leave_race()
	app.free()
	await process_frame
	print("RACE_TICKET_ROAD_OVERLAP: ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
