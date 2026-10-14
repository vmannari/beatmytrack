extends SceneTree
## Real callbacks and deliberately delayed disposable persistence, no player IO.
const Monitor = preload("res://diagnostics/race_hitch_monitor.gd")
var checks: int = 0
var failures: int = 0
var output: String

class SlowRecords extends LocalRecords:
	var delay_ms: int = 0
	func save_records() -> Error:
		if delay_ms > 0:
			OS.delay_msec(delay_ms)
			delay_ms = 0
		return OK

class LateCallback extends Node:
	var delay_ms: int = 0
	func _process(_delta: float) -> void:
		if delay_ms > 0:
			var wait_ms: int = delay_ms
			delay_ms = 0
			OS.delay_msec(wait_ms)

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func settle_frames(count: int = 5) -> void:
	for index: int in range(count): await process_frame

func run() -> void:
	output = ProjectSettings.globalize_path("res://../build/race-hitch-tests/%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(output)
	var game: Node = load("res://core/game.tscn").instantiate()
	var records := SlowRecords.new()
	game.preference_records = records
	game.initial_track = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	game.production_mode = true
	root.add_child(game)
	var monitor: Node = game.hitch_diagnostics
	monitor.persist_enabled = false
	monitor.log_path = output.path_join("race-callbacks.json")
	check(monitor != null and game.profile_enabled, "automatic capture needs no debug marker, login or server")
	game.countdown_ticks = 0
	game.paused = false
	await settle_frames()
	monitor.events.clear(); monitor.history.clear()
	await settle_frames()
	var late := LateCallback.new()
	late.process_priority = 100
	root.add_child(late)
	late.delay_ms = 1100
	await settle_frames()
	check(not monitor.events.is_empty(), "a late sibling callback outside Game is captured")
	var callback_events: Array = monitor.events.filter(func(event: Dictionary) -> bool: return event.frame.callbacks_ms >= 1000)
	check(not callback_events.is_empty(), "injected late callback is identified among renderer stalls")
	if not callback_events.is_empty():
		var row: Dictionary = callback_events[0].frame
		check(row.frame_ms >= 1000 and row.callbacks_ms >= 1000, "one-second wall-clock stall remains visible despite capped engine delta")
		check(row.stages_ms.process_total < 100, "external stall is distinguished from Game presentation")
		check(callback_events[0].before.size() > 0 and callback_events[0].after.size() > 0, "surrounding frames retained")
	monitor.events.clear()
	game.car_weathering.dirt_amount = 0.15
	records.delay_ms = 180
	game.condition_save_elapsed = 5.0
	await settle_frames()
	check(not monitor.events.is_empty(), "real five-second condition save stall captured")
	var save_events: Array = monitor.events.filter(func(event: Dictionary) -> bool: return event.frame.stages_ms.condition >= 170)
	check(not save_events.is_empty(), "injected save is identified among subsequent renderer stalls")
	if not save_events.is_empty():
		var row: Dictionary = save_events[0].frame
		check(row.stages_ms.condition >= 170 and row.stages_ms.process_total >= 170, "save duration is attributable without including network wait")
		check(row.condition_save_count > 0, "periodic save count recorded")
	check(Monitor._write_snapshot(output.path_join("observed-save.json"), monitor.snapshot()) == OK, "actual injected save evidence retained separately from synthetic stress")
	check(monitor.header.track_hash == game.native_track.content_hash and monitor.header.car == game.vehicle_id, "exact local track and car context recorded")
	check(not monitor.header.has("ticket") and not monitor.header.has("account") and not monitor.header.has("condition"), "diagnostics contain no credential, account or cosmetic snapshot")
	monitor.events.clear()
	game.paused = true
	await settle_frames()
	late.delay_ms = 180
	await settle_frames()
	check(monitor.events.is_empty(), "pause time does not masquerade as a racing freeze")
	game.paused = false
	await settle_frames()
	monitor._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	late.delay_ms = 180
	await settle_frames()
	monitor._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await settle_frames()
	check(monitor.events.is_empty(), "focus loss and resume do not create false hitches")
	monitor.set_process(false)
	monitor.console_enabled = false
	monitor.events.clear(); monitor.history.clear()
	for index: int in range(100):
		monitor.observe({"frame_ms": 100.0 + index, "tick": index, "countdown_ticks": 0}, true)
	check(monitor.events.size() == Monitor.MAX_EVENTS and monitor.history.size() == Monitor.HISTORY_FRAMES and monitor.dropped_events == 92, "events and frame history have hard bounds")
	check(monitor.events.all(func(event: Dictionary) -> bool: return event.frame.frame_ms >= 192), "full buffer retains worst hitches")
	for index: int in range(40): monitor.observe({"frame_ms": 8.0, "tick": 100 + index}, false)
	check(monitor.events.all(func(event: Dictionary) -> bool: return event.after.size() == Monitor.AFTER_FRAMES), "post-event capture has a hard bound")
	var payload: Dictionary = monitor.snapshot()
	monitor.events.clear()
	check(payload.events.size() == Monitor.MAX_EVENTS, "writer snapshot is detached from live event state")
	check(Monitor._write_snapshot(monitor.log_path, payload) == OK, "atomic local JSON capture written")
	var readback: Variant = JSON.parse_string(FileAccess.get_file_as_string(monitor.log_path))
	check(readback is Dictionary and readback.events.size() == Monitor.MAX_EVENTS and not FileAccess.file_exists(monitor.log_path + ".tmp"), "persisted log round-trips with no unfinished temporary")
	var unrelated := FileAccess.open(output.path_join("unrelated.txt"), FileAccess.WRITE)
	unrelated.store_string("keep"); unrelated.close()
	for index: int in range(12):
		check(Monitor._write_snapshot(output.path_join("race-retention-%02d.json" % index), payload) == OK, "bounded retention write %d" % index)
	var log_count: int = 0
	for filename: String in DirAccess.get_files_at(output):
		if filename.begins_with("race-") and filename.ends_with(".json"): log_count += 1
	check(log_count == Monitor.MAX_FILES and FileAccess.file_exists(output.path_join("unrelated.txt")), "rotation keeps eight diagnostic files and preserves other files")
	monitor.events = payload.events
	monitor.persist_enabled = true
	monitor.flush_async()
	var deadline: int = Time.get_ticks_msec() + 5000
	while monitor._thread != null and Time.get_ticks_msec() < deadline:
		monitor._reap_writer()
		await process_frame
	check(monitor._thread == null and monitor._saved_revision == monitor._revision, "asynchronous persistence completes without blocking a racing callback")
	game.set_physics_process(false)
	var state_before: Dictionary = RewindHistory.properties(game.sim.state)
	game._process(0.0)
	monitor._last_usec = 0
	monitor._process(0.0)
	check(RewindHistory.properties(game.sim.state) == state_before, "observer never advances canonical state")
	late.free()
	game.free()
	print("RACE_HITCH_TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
