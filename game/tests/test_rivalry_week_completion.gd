extends "res://tests/test_rivalry_result.gd"
## Delayed requests exercise the real finale button and scoped rollover adapter.
const Adapter = preload("res://backend/weekly_rivalry_client.gd")

class DelayedClient extends Node:
	signal reply_ready
	signal result_ready
	var player: Dictionary = {"id":"driver_2"}
	var development: bool = false
	var keys: int = 0
	var calls: Array[Dictionary] = []
	var pending_path: String = ""
	var response: Dictionary = {}
	var result_response: Dictionary = {}
	func base_url() -> String: return "http://week-fixture.invalid"
	func signed_in() -> bool: return true
	func test_drivers_available() -> bool: return development
	func new_operation_key() -> String:
		keys += 1
		return "week-key-"+str(keys)
	func recent_run(_ticket: String) -> Dictionary: return {}
	func request_api(path: String, method: int, payload: Dictionary, key: String, authorized: bool) -> Dictionary:
		calls.append({"path":path,"method":method,"payload":payload.duplicate(true),"key":key,"authorized":authorized})
		if path.ends_with("/result"):
			await result_ready
			return result_response.duplicate(true)
		pending_path = path
		await reply_ready
		return response.duplicate(true)
	func respond(value: Dictionary) -> void:
		response = value
		pending_path = ""
		reply_ready.emit()

var service: DelayedClient
var adapter: Node
var completed_snapshot: Dictionary
var active_snapshot: Dictionary

func prepare() -> void:
	adapter.reset()
	adapter.test_population = service.development
	adapter.model.apply_snapshot(completed_snapshot)
	adapter.snapshot_scope = adapter.scope()
	adapter.model.last_result = {"valid":true,"ms":100000}
	adapter.model.native_cache = {"old-track":"cached"}
	service.calls.clear()

func run() -> void:
	evidence = ProjectSettings.globalize_path("res://../docs/evidence/rivalry-week-completion-2026-10-12/ui")
	DirAccess.make_dir_recursive_absolute(evidence)
	OS.set_environment("BMT_API_URL","")
	service = DelayedClient.new()
	root.add_child(service)
	completed_snapshot = fixture()
	completed_snapshot.state = "complete"
	active_snapshot = fixture()
	active_snapshot.group_id = "current-week"
	active_snapshot.week = 42
	for row: Dictionary in active_snapshot.standings:
		row.points = 0; row.rank = null; row.completed = 0
	for track: Dictionary in active_snapshot.tracks:
		for row: Dictionary in track.entries:
			row.ms = null; row.ticks = null; row.rank = null; row.points = 0
	adapter = Adapter.new()
	adapter.client = service
	root.add_child(adapter)
	for development: bool in [false,true]:
		service.development = development
		prepare()
		adapter.continue_week()
		check(adapter.busy and adapter.request_scope == adapter.scope(),"Continue immediately owns the request and disables repeats")
		await adapter.continue_week()
		await adapter.refresh()
		check(service.calls.size() == 1,"double presses and timer refresh never overlap the acknowledgement")
		var first_key: String = service.calls[0].key
		service.respond({"ok":false,"data":{},"error":"CONNECTION_FAILED"})
		check(not adapter.busy and adapter.model.completed and not adapter.error.is_empty(),"failed acknowledgement retains the finale and enables retry")
		adapter.continue_week()
		check(service.calls[-1].key == first_key,"lost acknowledgement retries reuse the same operation key")
		service.respond({"ok":true,"data":{"acknowledged":true}})
		check(adapter.busy and service.pending_path == "/rivalry/join","one press joins the current week directly, bypassing old current snapshots")
		check(service.calls[-1].payload.get("test_population") == development and service.calls[-1].payload.get("automatic_test_drivers") == development,"current-week enrollment preserves real/development population")
		# Baseline used a current GET here, so this also proves that regression.
		service.respond({"ok":false,"data":{},"error":"CONNECTION_FAILED"})
		check(not adapter.busy and adapter.model.completed and not adapter.error.is_empty(),"failed enrollment preserves the reviewed finale for retry")
		adapter.continue_week()
		check(service.calls[-1].key == first_key,"retry after failed enrollment reuses the acknowledged operation")
		service.respond({"ok":true,"data":{"acknowledged":true}})
		service.respond({"ok":true,"data":active_snapshot})
		check(not adapter.busy and adapter.model.group_id == "current-week" and adapter.model.status == "active" and adapter.model.tracks.size() == 5,"one retry finishes on all five current-week tracks")
		check(adapter.model.last_result.is_empty() and adapter.model.native_cache.is_empty() and adapter.result_ticket.is_empty(),"new week clears previous result and native preview state")
		check(not adapter.cached_snapshot and adapter.snapshot_scope == adapter.scope(),"new week is authoritative in the current scope")
	prepare()
	adapter.result_ticket = "old-week-ticket"
	adapter.poll_result()
	check(adapter.result_polling,"old week's result request starts before Continue")
	adapter.continue_week()
	service.respond({"ok":true,"data":{"acknowledged":true}})
	service.respond({"ok":true,"data":active_snapshot})
	service.result_response = {"ok":true,"data":{"status":"rejected"}}
	service.result_ready.emit()
	check(adapter.model.group_id == "current-week" and adapter.error.is_empty() and not adapter.result_polling,"late old-week result cannot overwrite the next week or add an error")
	prepare()
	adapter.continue_week()
	adapter.reset()
	service.player.id = "other-account"
	service.respond({"ok":true,"data":{"acknowledged":true}})
	check(service.calls.size() == 1 and adapter.model.tracks.is_empty() and not adapter.busy,"account reset fences a late acknowledgement and prevents enrollment")
	service.player.id = "driver_2"
	prepare()
	adapter.continue_week()
	service.respond({"ok":true,"data":{"acknowledged":true}})
	adapter.reset()
	service.respond({"ok":true,"data":active_snapshot})
	check(adapter.model.tracks.is_empty() and not adapter.busy,"reset fences a late enrollment response")
	prepare()
	adapter.model.status = "settling"
	adapter.model.completed = false
	await adapter.continue_week()
	check(service.calls.is_empty(),"settling results cannot be acknowledged")
	prepare()
	adapter.snapshot_scope = "different-car"
	await adapter.continue_week()
	check(service.calls.is_empty(),"an out-of-scope finale cannot be acknowledged")
	adapter.queue_free()
	await process_frame
	await app_flow()
	service.queue_free()
	await process_frame
	print("RIVALRY_WEEK_COMPLETION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func app_flow() -> void:
	var folder: String = "user://rivalry_week_completion_"+TrackLibrary.unique_id()
	app = load("res://core/app.tscn").instantiate()
	app.library = TrackLibrary.new(folder.path_join("tracks"))
	app.records = LocalRecords.new(folder.path_join("records.json"))
	app.cloud_root_override = folder.path_join("cloud")
	root.add_child(app)
	while not app.startup_complete: await process_frame
	adapter = app.rivalry
	adapter.client = service
	service.development = false
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(960,540)]:
		root.size = dimensions
		prepare()
		app.rivalry_section = "overview"
		app._show_screen("rivalry")
		await settle()
		var next: Button = app.content.find_child("RivalryNextWeek",true,false)
		check(next != null and not next.disabled,"complete week exposes one usable Continue action")
		if DisplayServer.get_name() != "headless": await capture("finale",dimensions)
		next.pressed.emit()
		await settle()
		next = app.content.find_child("RivalryNextWeek",true,false)
		check(next != null and next.disabled,"actual rebuilt finale disables Continue during acknowledgement")
		if DisplayServer.get_name() != "headless": await capture("continuing",dimensions)
		service.respond({"ok":true,"data":{"acknowledged":true}})
		await settle()
		next = app.content.find_child("RivalryNextWeek",true,false)
		check(next != null and next.disabled,"Continue remains disabled throughout enrollment")
		service.respond({"ok":true,"data":active_snapshot})
		await settle()
		check(app.screen == "rivalry" and app.rivalry_section == "overview" and app.content.find_child("RivalryNextWeek",true,false) == null,"single finale press replaces the completed week with current overview")
		check(adapter.model.week == 42 and adapter.model.tracks.size() == 5 and not adapter.busy,"current week is fully populated and ready for racing")
		if DisplayServer.get_name() != "headless": await capture("next-week",dimensions)
	app.queue_free()
	await process_frame
