extends SceneTree
const Economy = preload("res://backend/cosmetic_economy.gd")
const Preloader = preload("res://backend/comparison_preloader.gd")
const Shop = preload("res://persistence/cosmetic_catalog.gd")
var checks: int = 0
var failures: int = 0
var foreground: Dictionary = {}
var foreground_done: bool = false

class WalletClient extends Node:
	signal identity_changed
	var player: Dictionary = {"id":"reuse-alice"}
	var state: Dictionary = {"schema":1,"revision":0,"balance":2000,"owned":[],"prices":{}}
	var completion: Dictionary = {}
	var receipt: Dictionary = {"status":"credited","amount":50,"rows":[{"title":"Finish","icon":"coin","amount":50,"eligible":true,"status":"Credited"}]}
	var calls: Array[String] = []
	var receipts: Dictionary = {}
	var hold: bool = false
	var lose_purchase: bool = false
	var charges: int = 0
	func signed_in() -> bool: return true
	func base_url() -> String: return "http://reuse-fixture.invalid"
	func new_operation_key() -> String: return "reuse-operation-"+str(calls.size())
	func recent_completion(ticket: String) -> Dictionary: return completion if ticket == "bundled" else {}
	func request_api(path: String, _method: int = 0, body: Dictionary = {}, key: String = "", _auth: bool = false) -> Dictionary:
		calls.append(path)
		state.prices = preload("res://persistence/cosmetic_catalog.gd").items()
		var data: Dictionary = state.duplicate(true)
		if path.begins_with("/economy/rewards/"): data = receipt.duplicate(true)
		if path == "/economy/purchases":
			if receipts.has(key): data = receipts[key].duplicate(true)
			else:
				state.balance -= int(state.prices[body.item_id])
				state.revision += 1
				state.owned.append(body.item_id)
				charges += 1
				data = {"item_id":body.item_id,"wallet":state.duplicate(true)}
				receipts[key] = data.duplicate(true)
				if lose_purchase:
					lose_purchase = false
					return {"ok":false,"status":0,"data":{},"error":"NETWORK_ERROR"}
		while hold: await get_tree().process_frame
		return {"ok":true,"status":200,"data":data,"error":""}

class ComparisonClient extends Node:
	var player: Dictionary = {"id":"reuse-alice"}
	func base_url() -> String: return "http://reuse-fixture.invalid"
	var packet: Dictionary = {}
	var hold: bool = true
	var paths: Array[String] = []
	func signed_in() -> bool: return true
	func request_api(path: String, _method: int = 0, _body: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		paths.append(path)
		while hold: await get_tree().process_frame
		return {"ok":true,"data":packet.duplicate(true)}
	func request_public(path: String, _owner: int) -> Dictionary:
		paths.append(path)
		while hold: await get_tree().process_frame
		return {"ok":true,"data":{"items":[]}}

func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)

func settle() -> void:
	for frame: int in range(8): await process_frame

func fetch_selected(loader: RefCounted) -> void:
	foreground = await loader.fetch("fixture-5","compact")
	foreground_done = true

func run() -> void:
	var directory: String = "user://backend-reuse-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	var client := WalletClient.new()
	root.add_child(client)
	var economy: Node = Economy.new()
	economy.records = records
	economy.client = client
	root.add_child(economy)
	await economy.refresh()
	check(client.calls.size() == 1 and economy.balance() == 2000,"first wallet access revalidates persisted state")
	for repeat: int in range(10): await economy.refresh()
	check(client.calls.size() == 1,"ten quick menu refreshes reuse the current wallet")
	economy._read_at = -Economy.FRESH_MS
	await economy.refresh()
	check(client.calls.size() == 2,"wallet freshness expires without advancing the system clock")
	client.state.balance += 50
	client.state.revision += 1
	client.completion = {"reward":client.receipt.duplicate(true),"wallet":client.state.duplicate(true)}
	var before: int = client.calls.size()
	var reward: Dictionary = await economy.reward_for("bundled")
	check(reward.amount == 50 and economy.balance() == 2050 and client.calls.size() == before,"completion receipt replaces both reward and wallet follow-ups")
	client.state.balance += 50
	client.state.revision += 1
	await economy.reward_for("fallback")
	await settle()
	check(economy.balance() == 2100 and client.calls.size() == before+2,"legacy credited rewards force refresh even inside freshness window")
	before = client.calls.size()
	check(await economy.purchase("livery/apex_twin"),"server-authorized purchase succeeds")
	await economy.refresh()
	check(client.calls.size() == before+1 and economy.balance() == 1600,"purchase receipt supplies a fresh authoritative wallet")
	client.lose_purchase = true
	check(not (await economy.purchase("livery/endurance")) and not economy.pending.is_empty(),"lost acknowledgement retains its purchase operation")
	var saved_key: String = economy.pending.key
	economy._read_at = Time.get_ticks_msec()
	await economy.refresh()
	check(economy.pending.is_empty() and client.receipts.has(saved_key) and client.charges == 2,"pending recovery bypasses freshness and never charges twice")
	client.hold = true
	economy.refresh(true)
	await process_frame
	client.state.balance += 75
	client.state.revision += 1
	economy.refresh(true)
	client.hold = false
	await settle()
	check(economy.balance() == client.state.balance and not economy._refresh_again,"forced refresh during an older read schedules a current follow-up")
	client.hold = true
	economy.refresh(true)
	await process_frame
	client.player = {"id":"reuse-bob"}
	client.identity_changed.emit()
	client.hold = false
	await settle()
	check(economy.wallet.is_empty() and economy.pending.is_empty(),"late wallet responses cannot populate another account")
	economy.queue_free();client.queue_free()
	await process_frame
	var service := ComparisonClient.new()
	service.packet = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/instant-comparisons-2026-10-10/slippery-compact-packet.json")).packet
	root.add_child(service)
	var loader := Preloader.new()
	loader.configure(service,"","reuse/account-a")
	var entries: Array = []
	for index: int in range(6): entries.append({"version_id":"fixture-%d" % index})
	loader.prime(entries,"compact")
	loader.prime(entries,"compact")
	check(Preloader.MAX_TARGETS == 2 and service.paths.size() == 4,"six cold candidates cause only two speculative comparisons and leaderboards")
	check(loader.diagnostics().speculative_started == 2,"speculative requests are counted once")
	fetch_selected(loader)
	check(loader._foreground_active == 1 and service.paths.size() == 6,"a selected track bypasses the held background allowance")
	service.hold = false
	await settle()
	check(foreground_done and foreground.has("packet"),"foreground still receives the complete real comparison packet")
	await loader.fetch("fixture-0","compact")
	await loader.fetch("fixture-0","compact")
	check(loader.diagnostics().speculative_used == 1,"using a prefetched comparison is counted once")
	loader.configure(service,"","reuse/account-b")
	check(loader.diagnostics().speculative_started == 0 and loader.peek("fixture-0","compact").is_empty(),"account changes clear cache and local diagnostics")
	service.queue_free()
	await process_frame
	print("BACKEND_REUSE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
