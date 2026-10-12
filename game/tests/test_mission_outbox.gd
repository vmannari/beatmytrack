extends SceneTree
## Actual durable CloudTracks outbox with controlled delayed transport responses.
const Cloud = preload("res://backend/cloud_tracks.gd")
var checks: int = 0
var failures: int = 0

class HeldClient extends Node:
	signal respond
	var player: Dictionary = {"id":"mission-alice"}
	var origin: String = "http://127.0.0.1:1"
	var held: bool = true
	var requests: Array[Dictionary] = []
	var _capabilities: Dictionary = {}
	func signed_in() -> bool: return not player.is_empty()
	func base_url() -> String: return origin
	func server_now() -> int: return 1000
	func new_operation_key() -> String: return "mission-retry-key-unchanged"
	func _background(work: Callable) -> Variant: return work.call()
	func submit_run(ticket_id: String, _frames: Array, key: String, _rewinds: Array = [], _proof: Dictionary = {}, _ghost: Dictionary = {}) -> Dictionary:
		requests.append({"owner":player.id,"origin":origin,"ticket":ticket_id,"key":key})
		if held: await respond
		return {"ok":true,"status":202,"data":{"run_id":"mission-accepted-run","status":"verified","time_ticks":100,"lap_ticks":[20,20,20,20,20]}}
	func request_api(_path: String, _method: HTTPClient.Method = HTTPClient.METHOD_GET, _data: Dictionary = {}, _key: String = "", _auth: bool = false) -> Dictionary:
		return {"ok":true,"status":200,"data":{"run_id":"mission-accepted-run","status":"verified","time_ticks":100,"lap_ticks":[20,20,20,20,20]}}

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ",label)

func finish_flush(cloud: Node, state: Dictionary) -> void:
	await cloud.flush_outbox()
	state.done = true

func run() -> void:
	var client := HeldClient.new()
	root.add_child(client)
	var cloud := Cloud.new()
	cloud.client = client
	cloud.root_override = "user://mission_outbox_"+TrackLibrary.unique_id()
	root.add_child(cloud)
	var saved_root: String = cloud.root_override
	var ticket_data: Dictionary = {"ticket_id":"mission-original-ticket","_owner_id":"mission-alice","_origin":client.origin,"_submit_key":"mission-original-key"}
	check(cloud.queue_run(ticket_data,[[0,255,0],[0,255,0]]),"original owner replay saved atomically")
	var alice_path: String = cloud.outbox_path()
	var state: Dictionary = {"done":false}
	finish_flush(cloud,state)
	for attempt: int in range(100):
		if not client.requests.is_empty(): break
		await process_frame
	check(client.requests.size() == 1,"upload reached controlled in-flight barrier")
	client.player = {"id":"mission-bob"}
	check(cloud.outbox_path() != alice_path,"account switch uses a separate durable scope")
	client.respond.emit()
	for attempt: int in range(100):
		if state.done: break
		await process_frame
	check(state.done,"late response completed without blocking the new account")
	check(cloud.upload_jobs().is_empty(),"late Alice response creates no Bob job or result")
	client.player = {"id":"mission-alice"}
	var pending: Array[Dictionary] = cloud.upload_jobs()
	check(pending.size() == 1 and not pending[0].has("done"),"original owner evidence remains pending after account switch")
	check(pending.size() == 1 and pending[0].key == "mission-original-key","original operation identity retained")
	cloud.queue_free()
	await process_frame
	# Recreate the actual adapter to prove the job is on disk, not only in memory.
	var restored := Cloud.new()
	restored.client = client
	restored.root_override = saved_root
	root.add_child(restored)
	client.held = false
	await restored.flush_outbox()
	var completed: Array[Dictionary] = restored.upload_jobs()
	check(completed.size() == 1 and completed[0].get("done",false),"original owner recovers the saved race after adapter restart")
	check(client.requests.size() == 2 and client.requests[0] == client.requests[1],"retry preserves original account/origin/ticket/key")
	check(completed.size() == 1 and completed[0].run_id == "mission-accepted-run","same accepted server run recovered")
	client.player = {"id":"mission-bob"}
	check(restored.upload_jobs().is_empty(),"verified Alice result remains absent from Bob history")
	print("MISSION_OUTBOX ",checks," checks, ",failures," failures")
	restored.queue_free()
	client.queue_free()
	await process_frame
	quit(1 if failures else 0)
