extends SceneTree
## Actual App lifecycle wiring. Result sessions are fixtures, not driven races.
const Telemetry = preload("res://backend/product_telemetry.gd")
var checks: int = 0
var failures: int = 0
var app: Node
class Client extends Node:
	var player: Dictionary = {"id":"app-quality-fixture"}
	var requests: int = 0
	func quality_supported() -> bool: return true
	func quality_schema_version() -> int: return 3
	func telemetry_supported() -> bool: return true
	func signed_in() -> bool: return true
	func base_url() -> String: return "http://127.0.0.1:18181"
	func server_now() -> int: return 0
	func auth_busy() -> bool: return false
	func cancel_telemetry() -> void: pass
	func request_telemetry(_payload: Dictionary) -> Dictionary:
		requests += 1
		return {"ok":false,"status":503}
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+label)
func packages() -> Array:
	return app.product_telemetry.queue.filter(func(entry: Dictionary) -> bool: return entry.event.name == "race_statistics")
func freeze_game() -> void:
	app.game.set_physics_process(false); app.game.set_process(false)
func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var directory: String = "user://race_statistics_app_"+Telemetry.uuid()
	DirAccess.make_dir_recursive_absolute(directory)
	app = (load("res://core/app.tscn") as PackedScene).instantiate()
	app.library = TrackLibrary.new(directory)
	app.records = LocalRecords.new(directory.path_join("records.json"))
	app.cloud_root_override = directory.path_join("cloud")
	root.add_child(app)
	var deadline: int = Time.get_ticks_msec()+10000
	while not app.startup_complete and Time.get_ticks_msec() < deadline: await process_frame
	check(app.startup_complete,"actual App startup completes with isolated local records")
	if not app.startup_complete:
		app.queue_free(); await process_frame; quit(1); return
	var client := Client.new(); root.add_child(client)
	app.product_telemetry._timer.stop(); app.product_telemetry._next_upload_msec = Time.get_ticks_msec()+3600000
	app.product_telemetry.client = client; app.product_telemetry.update_identity()
	app.product_telemetry.queue.clear(); app.product_telemetry._recount_budget()
	app.client_quality.set_process(false)
	app._show_screen("tracks")
	var track: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	track.metadata.cloud_version = Telemetry.uuid()
	app.selected_track = track
	await app._start_race(track,false,true)
	check(is_instance_valid(app.game) and app.client_quality._active,"actual normal race start begins a schema3 capture")
	if not is_instance_valid(app.game):
		app.queue_free(); client.queue_free(); await process_frame; quit(1); return
	freeze_game()
	app.client_quality.sample_frame("race",16); app.client_quality.sample_cell(0,Vector2.ZERO,false)
	check(packages().is_empty() and not app.product_telemetry._allowed,"race holds only local counters and closes optional transport")
	app._leave_race()
	check(packages().size() == 1 and packages()[0].event.properties.outcome == "abandoned","actual exit handler finalizes exactly one abandoned package")
	check(packages()[0].event.properties.render_context.car_detail == "full","actual instantiated car supplies its applied graphics setting")
	check(app.product_telemetry._allowed and not app.client_quality._active,"actual exit opens post-race persistence/transport")
	await process_frame
	app.selected_track = track
	app.records.settings.simple_car_models = true
	await app._start_race(track,false,true); freeze_game()
	check(app.client_quality._render_context.car_detail == "simple","next attempt captures the actual simple car model setting")
	var before_retry: String = app.client_quality._race_id
	app.client_quality.sample_frame("race",35)
	await app._retry_race(true); freeze_game()
	check(packages().size() == 2 and packages()[1].event.properties.outcome == "restarted" and packages()[1].event.id == before_retry,"actual retry handler finalizes the previous attempt once")
	check(app.client_quality._active and app.client_quality._race_id != before_retry,"retry on the same Game node begins a fresh capture")
	check(not app.product_telemetry._allowed,"retry leaves optional transport disabled")
	app.client_quality.sample_frame("race",17)
	var completed := TrackSession.new()
	completed.completed_laps = 5; completed.elapsed_ticks = 120*109; completed.lap_start_time = 109.0
	completed.lap_times.assign([22.0,21.0,23.0,22.0,21.0]); completed.finished = true
	app.game.track_session = completed; app.game.paused = true; app.game.attempt_practice = false
	app.game.emit_signal("race_completed")
	check(packages().size() == 3 and packages()[2].event.properties.outcome == "finished","actual race-completed/results callback creates one finished package")
	var completed_id: String = packages()[2].event.id
	app._results(); app._leave_race()
	check(packages().size() == 3 and packages()[2].event.id == completed_id,"duplicate results and later exit cannot duplicate a finished attempt")
	check(app.product_telemetry._allowed,"results/exit leave post-race transport enabled")
	await process_frame
	var local: NativeTrack = NativeTrack.read("res://resources/tracks/starter_circuit.json")
	local.metadata.erase("cloud_version"); app.selected_track = local
	await app._start_race(local,true,true); freeze_game()
	check(not app.client_quality._active,"actual creator/practice start excludes diagnostic capture")
	app._leave_race()
	check(packages().size() == 3,"creator practice exit emits no race statistics or draft geometry")
	check(client.requests == 0,"lifecycle integration sends no actual network requests")
	print("Race statistics App: %d checks, %d failures" % [checks,failures])
	app.queue_free(); client.queue_free(); await process_frame
	quit(1 if failures else 0)
