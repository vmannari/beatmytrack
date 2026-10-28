extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Economy = preload("res://backend/cosmetic_economy.gd")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: "+label)
func run() -> void:
	var client: Node = Client.new()
	root.add_child(client)
	check(client.configure(OS.get_environment("BMT_API_URL")) == OK,"configure isolated HTTP fixture")
	var boot: Dictionary = await client.request_api("/bootstrap")
	check(boot.ok and int(client._capabilities.get("run_completion_version",0)) == 1,"negotiate completion receipts")
	check(int(client._capabilities.get("discovery_preview_version",0)) == 1,"negotiate preview reuse")
	var login: Dictionary = await client.developer_login(OS.get_environment("BMT_DEV_AUTH_KEY"))
	check(login.ok,"authenticate invented account")
	var run_id: String = OS.get_environment("BMT_COMPLETION_RUN")
	var ticket: String = OS.get_environment("BMT_COMPLETION_TICKET")
	var response: Dictionary = await client.request_api(client.run_read_path("/runs/"+run_id),HTTPClient.METHOD_GET,{},"",true)
	check(response.ok and response.data.status == "verified","actual run response validates")
	check(client.recent_completion(ticket).get("wallet",{}).get("balance",0) == 1234,"client retains the exact completion wallet")
	var directory: String = "user://completion-http-"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(directory)
	var economy: Node = Economy.new()
	economy.client = client
	economy.records = LocalRecords.new(directory.path_join("records.json"))
	root.add_child(economy)
	var reward: Dictionary = await economy.reward_for(ticket)
	check(reward.get("amount",0) == 50 and economy.balance() == 1234,"economy consumes actual HTTP receipt without follow-up reads")
	var batch: Dictionary = await client.request_api(client.run_read_path("/runs/status?ids="+run_id),HTTPClient.METHOD_GET,{},"",true)
	check(batch.ok and batch.data.get("completion_wallet",{}).get("balance",0) == 1234,"batch response contains one account wallet")
	check(client.recent_completion(ticket).get("reward",{}).get("amount",0) == 50,"batch receipt is retained per ticket")
	client._race_status_cache.clear()
	var waited: Dictionary = await client.wait_for_run(run_id,ticket)
	check(waited.ok and client.recent_completion(ticket).get("wallet",{}).get("balance",0) == 1234,"wait response preserves receipts")
	economy.queue_free();client.queue_free()
	await process_frame
	print("COMPLETION_HTTP checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
