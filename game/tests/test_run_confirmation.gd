extends SceneTree
## Actual completion/cache/outbox adapters; transport gates control late receipts.
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0

class WaitingClient extends "res://backend/backend_client.gd":
	signal release
	var requests: int = 0
	var response: Dictionary = {}
	var delayed: bool = false
	func _ready() -> void: pass
	func _send(_path: String, _method: HTTPClient.Method, _payload: Dictionary, _authorized: bool, _key: String = "", _headers: PackedStringArray = PackedStringArray(), _owner: int = 0) -> Dictionary:
		requests += 1
		if delayed: await release
		return response.duplicate(true)

class WaitingEconomy extends Node:
	signal changed
	signal release
	var requests: int = 0
	func authenticated() -> bool: return true
	func balance() -> int: return 50
	func reward_for(_ticket: String) -> Dictionary:
		requests += 1
		if requests == 1:
			await release
			return {"status":"pending","amount":0,"rows":[]}
		return {"status":"credited","amount":50,"rows":[{"title":"Race completed","amount":50,"icon":"flag","eligible":true}]}

func _initialize() -> void: call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+description)

func receipt(run_id: String = "run-a", ticket_id: String = "ticket-a") -> Dictionary:
	return {"run_id":run_id,"ticket_id":ticket_id,"status":"verified","time_ticks":100,"lap_ticks":[20,20,20,20,20],"outcome":null,"slot":null}

func collect(client: Node, run_id: String, ticket_id: String, target: Dictionary) -> void:
	target.response = await client.wait_for_run(run_id,ticket_id)
	target.done = true

func run() -> void:
	var client := WaitingClient.new()
	root.add_child(client)
	client._base_url = "http://127.0.0.1:8080"
	client._access_token = "owned-test-token"
	client.player = {"id":"driver-a"}
	client._capabilities = {"run_wait_ms":2000}
	client.response = {"ok":true,"status":200,"data":receipt(),"error":""}
	client.delayed = true
	var first: Dictionary = {"done":false}
	var second: Dictionary = {"done":false}
	collect(client,"run-a","ticket-a",first)
	collect(client,"run-a","ticket-a",second)
	await process_frame
	check(client.requests == 1 and client.run_wait_pending("ticket-a"),"matching callers share one foreground request")
	var busy: Dictionary = await client.wait_for_run("run-b","ticket-b")
	check(busy.error == "WAIT_BUSY" and client.requests == 1,"one foreground wait bounds client requests")
	client.release.emit()
	for frame: int in range(4): await process_frame
	check(first.done and second.done and first.response.ok and second.response.ok,"both coalesced callers receive the exact receipt")
	check(client.recent_run("ticket-a").run_id == "run-a" and not client.run_wait_pending("ticket-a"),"terminal receipt is cached before wait retires")
	client._race_status_cache.clear()
	client.delayed = false
	client.response.data = receipt("wrong-run","ticket-b")
	var wrong: Dictionary = await client.wait_for_run("run-b","ticket-b")
	check(not wrong.ok and wrong.error == "INVALID_RESPONSE" and client.recent_run("ticket-b").is_empty(),"wrong run cannot enter the receipt cache")
	client.response.data = receipt("run-b","wrong-ticket")
	wrong = await client.wait_for_run("run-b","ticket-b")
	check(not wrong.ok and client.recent_run("wrong-ticket").is_empty(),"wrong ticket cannot enter the receipt cache")
	client.delayed = true
	client.response.data = receipt("run-b","ticket-b")
	var stale: Dictionary = {"done":false}
	collect(client,"run-b","ticket-b",stale)
	await process_frame
	client.clear_session()
	client.player = {"id":"driver-b"}
	client._access_token = "owned-new-session-token"
	client.release.emit()
	for frame: int in range(4): await process_frame
	check(stale.done and not stale.response.ok and client.recent_run("ticket-b").is_empty(),"late receipt cannot cross account generation")
	client.delayed = false
	client.response = {"ok":false,"status":404,"data":{},"error":"NOT_FOUND"}
	var unavailable: Dictionary = await client.wait_for_run("run-b","ticket-b")
	var count: int = client.requests
	await client.wait_for_run("run-b","ticket-b")
	check(not unavailable.ok and int(client._capabilities.run_wait_ms) == 0 and client.requests == count,"older endpoint disables foreground waits and retains polling fallback")
	client._capabilities.run_wait_ms = 2000
	client.response = {"ok":true,"status":200,"data":receipt(),"error":""}
	client.player = {"id":"driver-a"}
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = "user://run_confirmation_"+TrackLibrary.unique_id()
	root.add_child(cloud)
	check(cloud.queue_run({"ticket_id":"ticket-a"},[[0,255,0]]),"completion fixture is durably queued")
	var job: Dictionary = cloud.upload_job("ticket-a")
	job.run_id = "run-a"
	cloud._save_job(str(job._path),job)
	check(cloud.upload_job("ticket-a").get("run_id","") == "run-a","durable receipt identity is attached")
	await client.wait_for_run("run-a","ticket-a")
	count = client.requests
	await cloud.flush_outbox()
	check(cloud.upload_job("ticket-a").get("done",false) and client.requests == count,"completed cache retires the durable outbox without another HTTP status read")
	var economy := WaitingEconomy.new()
	root.add_child(economy)
	var page := RaceComplete.new()
	page.results = RaceResults.new()
	page.results.circuit = "Fixture"
	page.economy = economy
	page.reward_ticket = "ticket-a"
	page.cloud_client = client
	root.add_child(page)
	for frame: int in range(3): await process_frame
	check(economy.requests == 1 and page.get_meta("coin_polling",false),"reward view starts one coalesced receipt read")
	client.run_completed.emit()
	client.run_completed.emit()
	economy.release.emit()
	for frame: int in range(6): await process_frame
	check(economy.requests == 2 and page.coin_receipt.get("status") == "credited" and page._receipt_timer.is_stopped(),"confirmation during a pending receipt read refreshes Coins without the two-second timer")
	client.run_completed.emit()
	await process_frame
	check(economy.requests == 2,"settled rewards stay quiet on repeated completion events")
	page.results.free()
	page.queue_free()
	economy.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame
	print("RUN_CONFIRMATION_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
