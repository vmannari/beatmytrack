extends SceneTree
## A real isolated-service snapshot crosses the native boundary, including stage selection.
var checks: int = 0
var failures: int = 0

class StubClient extends Node:
	var player: Dictionary = {"id":"series-fixture"}
	var _capabilities: Dictionary = {"challenge_series_version":1}
	var path: String = ""
	func base_url() -> String: return "http://series-fixture"
	func server_now() -> int: return 0
	func signed_in() -> bool: return true
	func new_operation_key() -> String: return "series-operation-"+str(Time.get_ticks_usec())
	func request_api(value: String, _method: int, _body: Dictionary, _key: String, _auth: bool) -> Dictionary:
		path = value
		return {"ok":true,"data":{"expires_at":9999999999,"attempt_limit":3,"attempts_used":1,"attempts_remaining":2}}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+detail)

func run() -> void:
	OS.set_environment("BMT_API_URL","")
	root.content_scale_size = Vector2i.ZERO
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/challenge_series_v1.json"))
	check(ChallengesClient.valid_snapshot(snapshot),"actual server 3×3 snapshot is accepted by native validation")
	for kind: String in ["missing","duplicate","tries","car","total","completion"]:
		var bad: Dictionary = snapshot.duplicate(true)
		match kind:
			"missing": bad.stages.remove_at(2)
			"duplicate": bad.stages[2].entry = bad.stages[1].entry
			"tries": bad.stages[1].attempts_remaining = 4
			"car": bad.stages[2].manifest.vehicle_id = "pickup"
			"total": bad.standings[0].ticks = 648001
			"completion": bad.standings[0].completed_tracks = 4
		check(not ChallengesClient.valid_snapshot(bad),"malformed series is rejected: "+kind)
	var client := StubClient.new()
	root.add_child(client)
	var cloud: Node = load("res://backend/cloud_tracks.gd").new()
	cloud.client = client
	cloud.root_override = "user://series-contract-"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var adapter := ChallengesClient.new()
	adapter.client = client
	adapter.cloud = cloud
	root.add_child(adapter)
	adapter.reset()
	adapter.selected = snapshot.duplicate(true)
	for stage: int in range(3):
		adapter.select_stage(stage)
		check(adapter.race_stage().entry == snapshot.stages[stage].entry,"race selection uses the actual stage "+str(stage))
		await adapter.ticket()
		check(client.path.ends_with("/tickets?stage="+str(stage)),"ticket request pins stage "+str(stage))
		check(adapter.race_stage().attempts_remaining == 2,"ticket updates only the selected track budget")
		await adapter.ghost()
		check(client.path.ends_with("/ghost?stage="+str(stage)),"ghost request uses stage "+str(stage))
	check(preload("res://backend/backend_client.gd")._race_ticket_path("/challenges/AB12CD34EF56AB78/tickets?stage=2"),"stage query retains independent race-ticket authentication")
	root.size = Vector2i(1280,720)
	for result: bool in [false,true]:
		var page := ChallengesPage.new()
		page.selected = snapshot.duplicate(true)
		page.items.assign([snapshot])
		page.selected_stage = 2
		page.signed_in = true
		page.result_view = result
		root.add_child(page)
		MenuStyle.fill(page)
		await process_frame
		await process_frame
		for stage: int in range(3): check(page.find_child("ChallengeStage_"+str(stage),true,false) != null,"all tracks remain directly selectable")
		check(not (page.find_child("ChallengeRace",true,false) as Button).disabled,"available selected stage enables race")
		page.queue_free()
		await process_frame
	for dimensions: Vector2i in [Vector2i(1280,720),Vector2i(844,390)]:
		root.size = dimensions
		var ready := preload("res://ui/challenge_ready_dialog.gd").new()
		ready.snapshot = snapshot.duplicate(true)
		root.add_child(ready)
		preload("res://ui/popup_style.gd").watch(ready)
		ready.popup_centered(Vector2i(mini(700,dimensions.x-32),mini(600,dimensions.y-32)))
		for frame: int in range(6): await process_frame
		check(ready.position.x >= 0 and ready.position.y >= 0 and ready.size.x <= dimensions.x and ready.size.y <= dimensions.y,"three-track invitation fits "+str(dimensions)+" actual "+str(ready.position)+" "+str(ready.size))
		ready.queue_free()
		await process_frame
	adapter.queue_free()
	cloud.queue_free()
	client.queue_free()
	await process_frame
	print("CHALLENGE_SERIES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures > 0 else 0)
