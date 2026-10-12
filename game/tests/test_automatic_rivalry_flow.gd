extends SceneTree
## Automatic entry must preserve the finale and fence a disabled service.
const Adapter = preload("res://backend/weekly_rivalry_client.gd")
var checks: int = 0
var failures: int = 0

class Service extends Node:
	var player: Dictionary = {"id":"observer"}
	var enabled: bool = true
	var state: String = "not_joined"
	var automatic: bool = false
	var joins: int = 0
	var week: int = 41
	var keys: int = 0
	func base_url() -> String: return "http://127.0.0.1:18181"
	func signed_in() -> bool: return true
	func test_drivers_available() -> bool: return enabled
	func new_operation_key() -> String:
		keys += 1
		return "fixture-key-"+str(keys)
	func request_api(path: String, _method: int, payload: Dictionary, _key: String, _authorized: bool) -> Dictionary:
		if path == "/rivalry/join":
			assert(payload.test_population and payload.automatic_test_drivers)
			joins += 1
			state = "active"
			automatic = true
		elif path.ends_with("/continue"):
			week += 1
			state = "not_joined"
			automatic = false
		return {"ok":true,"data":snapshot()}
	func snapshot() -> Dictionary:
		var data: Dictionary = {"state":state,"week":week,"ends_at":604800,"server_now":0,"automatic_test_drivers":automatic,"test_population":enabled}
		if state == "not_joined": return data
		data.group_id = "fixture-group"
		data.self_id = "observer"
		data.vehicle_id = "compact"
		data.standings = [{"id":"observer","name":"Observer","rank":null,"points":0}]
		data.tracks = []
		for slot: int in range(5):
			data.tracks.append({"board_id":"board_"+str(slot),"entries":[{"id":"observer","name":"Observer","ms":null,"rank":null,"points":0}],"entry":{"name":"Circuit "+str(slot),"creator":"Beat my track","track_id":"track_"+str(slot),"version_id":"version_"+str(slot),"content_hash":"a".repeat(64),"points":[]}})
		return data

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	var service := Service.new()
	var adapter: Node = Adapter.new()
	adapter.client = service
	adapter.add_child(service)
	root.add_child(adapter)
	await adapter.refresh()
	check(adapter.test_population and adapter.model.status == "active" and service.joins == 1,"development service opens a test rivalry without a selector")
	await adapter.refresh()
	check(service.joins == 1,"an automatic field refresh never enrolls again")
	service.automatic = false
	await adapter.refresh()
	check(service.joins == 2,"an existing manual test field is adopted automatically")
	service.state = "complete"
	service.automatic = false
	await adapter.refresh()
	check(adapter.model.completed and service.joins == 2,"an older completed week stays visible for finale review")
	await adapter.continue_week()
	check(adapter.model.week == 42 and adapter.model.status == "active" and service.joins == 3,"Continue automatically opens the new week's development field")
	var old_scope: String = adapter.scope()
	service.enabled = false
	service.state = "not_joined"
	await adapter.refresh()
	check(not adapter.test_population and adapter.scope() != old_scope and adapter.model.tracks.is_empty() and service.joins == 3,"a disabled service fences the old test field and never enrolls fake entrants")
	var malformed: Dictionary = service.snapshot()
	malformed.automatic_test_drivers = "true"
	check(not Adapter.valid_snapshot(malformed),"a malformed automatic marker cannot enter client state")
	adapter.queue_free()
	await process_frame
	print("AUTOMATIC_RIVALRY_FLOW: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
