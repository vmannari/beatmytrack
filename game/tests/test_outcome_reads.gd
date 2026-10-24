extends SceneTree
## Real consumers: negotiated reads, exact receipts, late replies and live refresh.
const Client = preload("res://backend/backend_client.gd")
const Economy = preload("res://backend/cosmetic_economy.gd")
const Shop = preload("res://persistence/cosmetic_catalog.gd")
var checks: int = 0
var failures: int = 0

class Stub extends "res://backend/backend_client.gd":
	signal release
	var answer: Dictionary = {"ok":true,"status":200,"data":{},"error":""}
	var calls: int = 0
	var last_path: String = ""
	var delay: bool = false
	func _ready() -> void: pass
	func request_api(path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		calls += 1
		last_path = path
		var value: Dictionary = answer.duplicate(true)
		if delay: await release
		return value

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func wallet(balance: int, revision: int) -> Dictionary:
	return {"schema":1,"balance":balance,"revision":revision,"owned":[],"prices":Shop.items()}

func reward() -> Dictionary:
	return {"status":"credited","amount":50,"rows":[{"title":"Race completed","amount":50,"icon":"flag","eligible":true,"status":"Credited"}]}

func run_value(ticket_id: String = "ticket-a") -> Dictionary:
	return {"run_id":"run-a","ticket_id":ticket_id,"board_id":"board-a","status":"verified","created_at":1,"finished_at":2,"time_ticks":100,"lap_ticks":[20,20,20,20,20],"failure_code":null,"retryable":false,"poll_after_ms":0,
		"completion":{"version":1,"reward":reward(),"wallet":wallet(900,3)}}

func snapshot() -> Dictionary:
	return {"id":"challenge","code":"AB12CD34EF56AB78","mode":"beat","state":"active","creator_id":"rival","creator":"Mika","self_id":"self","joined":true,"vehicle_id":"compact",
		"ends_at":604800,"server_now":432000,"remaining_seconds":172800,"manifest":{"laps":5,"tick_rate":120},"target_ticks":100,"target_ms":833,"attempt_limit":3,"attempts_used":0,"attempts_remaining":3,
		"entry":{"name":"Forest Run","version_id":"00000000-0000-0000-0000-000000000001","track_id":"00000000-0000-0000-0000-000000000002","content_hash":"a".repeat(64),"points":[[0,0],[100,0],[100,100]]},
		"share_url":"https://fixture/c/AB12CD34EF56AB78","standings":[{"id":"rival","name":"Mika","country_code":"FI","rank":1,"ticks":100,"ms":833,"run_id":"rival-run"},{"id":"self","name":"You","country_code":"FI","rank":null,"ticks":null,"ms":null,"run_id":null}]}

func pending() -> Dictionary:
	return {"schema":"bmt-challenge-pending-v1","status":"queued","failure_code":null,"outcome":null,"poll_after_ms":1000,
		"challenge_pending":{"id":"challenge","code":"AB12CD34EF56AB78","self_id":"self","state":"active","ends_at":604800,"server_now":432001,"remaining_seconds":172799,
		"attempt_limit":3,"attempts_used":1,"attempts_remaining":2,"rewards":{"finish":50,"goal":100,"finish_earned":false,"goal_earned":false,"eligible":true,"daily_limit":3,"remaining_today":3}}}

func poll(page: Node, state: Dictionary) -> void:
	await page.poll_result()
	state.done = true

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	var client := Stub.new()
	client.player = {"id":"self"}
	client._access_token = "owned-fixture-token"
	client._base_url = "http://fixture.invalid"
	client._capabilities = {"run_completion_version":1,"challenge_pending_version":1,"run_wait_ms":2000}
	root.add_child(client)
	check(client.run_read_path("/runs/a") == "/runs/a?completion=true","single completion opt-in")
	check(client.run_read_path("/runs/status?ids=a") == "/runs/status?ids=a&completion=true","batch query retains IDs")
	client._capabilities.erase("run_completion_version")
	check(client.run_read_path("/runs/a") == "/runs/a","older server keeps old read")
	client._capabilities.run_completion_version = 1
	var directory: String = "user://outcome_reads_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var records := LocalRecords.new(directory.path_join("records.json"))
	var economy := Economy.new()
	economy.records = records
	economy.client = client
	root.add_child(economy)
	client.remember_run(run_value())
	var receipt: Dictionary = await economy.reward_for("ticket-a")
	check(receipt.status == "credited" and economy.balance() == 900 and client.calls == 0,"combined receipt and absolute wallet avoid both GETs")
	await economy.reward_for("ticket-a")
	check(economy.balance() == 900 and client.calls == 0,"duplicate receipt never adds coins locally")
	economy.wallet = wallet(800,4)
	economy.wallet.owned = [str(Shop.items().keys()[0])]
	await economy.reward_for("ticket-a")
	check(economy.balance() == 800 and economy.wallet.revision == 4 and economy.wallet.owned.size() == 1,"late older wallet cannot undo a purchase or ownership")
	var bad: Dictionary = run_value("bad-ticket")
	bad.completion.reward.amount = 51
	client.remember_run(bad)
	client.answer.data = {"status":"unavailable","amount":0,"rows":[]}
	await economy.reward_for("bad-ticket")
	check(client.calls == 1 and client.last_path == "/economy/rewards/bad-ticket","malformed enrichment falls back independently")
	bad = run_value("archived-ticket")
	bad.completion.reward = null
	client.remember_run(bad)
	await economy.reward_for("archived-ticket")
	check(client.calls == 2,"archived receipt retains existing recovery endpoint")
	economy.pending = {"item_id":str(Shop.items().keys()[0]),"expected_price":500,"key":"owned-recovery-key"}
	client.answer.data = {"item_id":economy.pending.item_id,"wallet":wallet(400,5)}
	await economy.reward_for("ticket-a")
	for i: int in range(3): await process_frame
	check(economy.pending.is_empty() and economy.balance() == 400 and client.calls == 3,"combined wallet continues an existing idempotent purchase recovery")
	client.answer.data = run_value("wait-ticket")
	await client.wait_for_run("run-a","wait-ticket")
	check(client.last_path.ends_with("&completion=true") and not client.recent_completion("wait-ticket").is_empty(),"foreground wait negotiates and caches enrichment")
	var page := ChallengesClient.new()
	page.client = client
	page.selected = snapshot()
	page._scope = page.scope()
	root.add_child(page)
	check(ChallengesClient.valid_snapshot(page.selected),"full challenge fixture validates")
	page.begin_result("challenge-ticket")
	client.answer.data = pending()
	await page.poll_result()
	check(client.last_path.ends_with("?compact=true") and page.result_state == "queued","pending poll negotiates compact representation")
	check(page.selected.attempts_used == 1 and page.selected.attempts_remaining == 2 and page.selected.server_now == 432001,"compact result updates attempts and live clock")
	check(page.selected.standings.size() == 2,"compact update retains the loaded standings")
	page._next_full_result = 0
	page._next_poll = 0
	client.answer.data = {"status":"queued","poll_after_ms":1000,"challenge":snapshot()}
	await page.poll_result()
	check(not client.last_path.contains("compact") and page._next_full_result > Time.get_ticks_msec(),"periodic full read refreshes opponents and expiry")
	var terminal: Dictionary = run_value("challenge-ticket")
	terminal.completion.challenge_result = {"status":"verified","poll_after_ms":0,"failure_code":null,"outcome":{"counted":true},"challenge":snapshot()}
	client.remember_run(terminal)
	var count: int = client.calls
	await page.poll_result()
	check(page.result_state == "verified" and page.outcome.get("counted",false) and client.calls == count,"authorized terminal challenge data avoids its separate GET")
	client.invalidate_challenge_completions()
	check(not client.recent_completion("challenge-ticket").has("challenge_result"),"local safety change invalidates cached challenge views")
	page.begin_result("old-server-ticket")
	client._capabilities.erase("challenge_pending_version")
	client.answer.data = {"status":"queued","poll_after_ms":1000,"challenge":snapshot()}
	await page.poll_result()
	check(not client.last_path.contains("compact") and page.result_state == "queued","old server continues with complete snapshots")
	page._next_poll = 0
	client.delay = true
	client.answer.data = {"status":"verified","poll_after_ms":0,"challenge":snapshot(),"outcome":{"counted":true}}
	var state: Dictionary = {"done":false}
	poll(page,state)
	await process_frame
	client.clear_session()
	client.player = {"id":"other"}
	client._access_token = "new-owned-fixture-token"
	client.release.emit()
	for i: int in range(4): await process_frame
	check(state.done and page.result_state == "queued" and client.recent_completion("ticket-a").is_empty(),"late results and receipt cache cannot cross accounts")
	page.queue_free()
	economy.queue_free()
	client.queue_free()
	await process_frame
	print("OUTCOME_READ_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
