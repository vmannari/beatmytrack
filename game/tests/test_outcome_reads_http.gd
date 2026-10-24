extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Economy = preload("res://backend/cosmetic_economy.gd")
var checks: int = 0
var failures: int = 0

class Tracking extends "res://backend/backend_client.gd":
	var calls: int = 0
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, key: String = "", authorized: bool = false) -> Dictionary:
		calls += 1
		return await super.request_api(path,method,payload,key,authorized)

func _initialize() -> void: call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+message)

func run() -> void:
	var client := Tracking.new()
	root.add_child(client)
	check(client.configure(OS.get_environment("BMT_API_URL")) == OK,"configure disposable API")
	var boot: Dictionary = await client.request_api("/bootstrap")
	check(boot.ok and client._capabilities.get("run_completion_version") == 1 and client._capabilities.get("challenge_pending_version") == 1,"negotiate both current protocols")
	var login: Dictionary = await client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.ok,"authenticate actual development session")
	var fixture: Dictionary = await client.request_api("/outcome-fixture",HTTPClient.METHOD_GET,{},"",true)
	check(fixture.ok,"read fixture identities")
	var ids: Dictionary = fixture.data
	var terminal: Dictionary = await client.request_api(client.run_read_path("/runs/"+str(ids.run_id)),HTTPClient.METHOD_GET,{},"",true)
	check(terminal.ok and Client.valid_run(terminal.data) and terminal.data.completion.reward.amount == 50,"decode real terminal receipt")
	var folder: String = "user://outcome_http_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var economy := Economy.new()
	economy.client = client
	economy.records = LocalRecords.new(folder.path_join("records.json"))
	root.add_child(economy)
	var count: int = client.calls
	var reward: Dictionary = await economy.reward_for(str(ids.ticket_id))
	check(reward.get("status") == "credited" and economy.balance() == 900 and client.calls == count,"real consumer avoids receipt and wallet requests")
	var challenge := ChallengesClient.new()
	challenge.client = client
	challenge.selected = terminal.data.completion.challenge_result.challenge
	challenge._scope = challenge.scope()
	root.add_child(challenge)
	challenge.begin_result(str(ids.ticket_id))
	count = client.calls
	await challenge.poll_result()
	check(challenge.result_state == "verified" and challenge.outcome.get("counted",false) and client.calls == count,"real authorized challenge receipt avoids another result request")
	client._race_status_cache.clear()
	var batch: Dictionary = await client.request_api(client.run_read_path("/runs/status?ids="+str(ids.run_id)+"&ids="+str(ids.pending_run)),HTTPClient.METHOD_GET,{},"",true)
	check(batch.ok and batch.data.items.size() == 2 and batch.data.has("completion_wallet"),"batch shares one account snapshot with pending status")
	count = client.calls
	await economy.reward_for(str(ids.ticket_id))
	check(client.calls == count and economy.balance() == 900,"transport attaches shared batch wallet to the receipt cache")
	var pending_path: String = "/challenge-results/"+str(ids.pending_ticket)+"?compact=true"
	var pending: Dictionary = await client.request_api(pending_path,HTTPClient.METHOD_GET,{},"",true)
	check(pending.ok and pending.data.get("schema") == "bmt-challenge-pending-v1" and not pending.data.has("challenge"),"HTTP pending response omits full snapshot")
	check(pending.data.challenge_pending.attempts_used == 2 and pending.data.challenge_pending.attempts_remaining == 1,"compact response retains authoritative starts")
	var old: Dictionary = await client.request_api("/challenge-results/"+str(ids.pending_ticket),HTTPClient.METHOD_GET,{},"",true)
	check(old.ok and ChallengesClient.valid_snapshot(old.data.get("challenge")),"ordinary client keeps the original complete response")
	var withdrawn: Dictionary = await client.request_api("/cost-fixture/disable",HTTPClient.METHOD_POST,{},client.new_operation_key(),true)
	check(withdrawn.ok,"withdraw owned fixture content")
	pending = await client.request_api(pending_path,HTTPClient.METHOD_GET,{},"",true)
	check(not pending.ok and pending.status == 404,"compact response enforces current content withdrawal")
	terminal = await client.request_api(client.run_read_path("/runs/"+str(ids.run_id)),HTTPClient.METHOD_GET,{},"",true)
	check(terminal.ok and terminal.data.status == "verified" and not terminal.data.completion.has("challenge_result"),"withdrawn optional view never hides durable race and reward")
	challenge.queue_free()
	economy.queue_free()
	client.queue_free()
	await process_frame
	print("OUTCOME_HTTP_TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
