extends SceneTree
const Client = preload("res://backend/backend_client.gd")
const Cloud = preload("res://backend/cloud_tracks.gd")
const RotationLock = preload("res://backend/session_rotation_lock.gd")
var checks: int = 0
var failures: int = 0
var folder: String

class API extends Client:
	var calls: Array[Dictionary] = []
	func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, body: Dictionary = {}, key: String = "", _auth: bool = false) -> Dictionary:
		calls.append({"path":path,"method":method,"body":body.duplicate(true),"key":key})
		if path == "/bootstrap": return {"ok":true,"status":200,"data":{"publication_workflow_version":2},"error":""}
		return {"ok":false,"status":429,"data":{},"error":"RATE_LIMITED","retry_after":90}

class RefusingCloud extends Cloud:
	func _write(path: String, value: Dictionary) -> bool:
		return false if ".publication-waits" in path else super._write(path,value)

class RetiringCloud extends Cloud:
	func _read(path: String) -> Dictionary:
		if path.ends_with(".wait.json"):
			DirAccess.remove_absolute(path)
			return {}
		return super._read(path)

func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: "+message)
func api(owner: String) -> API:
	var result := API.new()
	root.add_child(result)
	result.configure("http://127.0.0.1:1")
	result.player = {"id":owner}
	result._access_token = "fixture-access"
	return result
func flow(client: API, overridden: Node = null) -> TrackLifecycle:
	var cloud: Node = Cloud.new() if overridden == null else overridden
	cloud.client = client
	cloud.root_override = folder.path_join("cloud")
	root.add_child(cloud)
	var result := TrackLifecycle.new()
	result.cloud = cloud
	result.library = TrackLibrary.new(folder.path_join("drafts"))
	root.add_child(result)
	return result
func run() -> void:
	create_timer(25).timeout.connect(func() -> void: print("FAIL: communication follow-up timeout"); quit(1))
	folder = ProjectSettings.globalize_path("res://../build/communication-followup-native-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	var client: API = api("elapsed-owner")
	var first: TrackLifecycle = flow(client)
	first._pause_batch({"status":429,"retry_after":60})
	check(not first._batch_ready(),"fresh publication pause blocks processing")
	for deadline: String in first._batch_deadlines: first._batch_deadlines[deadline] = 0 # Advance only disposable monotonic deadlines.
	check(first._batch_ready(),"elapsed publication pause becomes ready")
	check(flow(client)._batch_ready(),"elapsed clockless pause stays elapsed after controller restart")
	check(DirAccess.get_files_at(first._wait_root()).is_empty(),"completed immutable waits release their files")
	var storage_refusal: TrackLifecycle = flow(api("refused-owner"),RefusingCloud.new())
	storage_refusal._pause_batch({"status":429,"retry_after":60})
	check(not storage_refusal._batch_ready(),"failed deadline persistence still blocks repeated requests in memory")
	var retiring: TrackLifecycle = flow(api("retiring-owner"),RetiringCloud.new())
	retiring._pause_batch({"status":429,"retry_after":60})
	check(retiring._batch_ready() and retiring.last_error.is_empty(),"concurrent expiry between listing and reading is not reported as corruption")
	var legacy_client: API = api("legacy-owner")
	var legacy: TrackLifecycle = flow(legacy_client)
	legacy.cloud._write(legacy._root().path_join("publication-retry.json"),{"schema":"publication-retry-1","scope":legacy.scope(),"nonce":"legacy-pause","delay":60,"server_at":0})
	check(not legacy._batch_ready(),"legacy pause files still enforce their full wait")
	for deadline: String in legacy._batch_deadlines: legacy._batch_deadlines[deadline] = 0
	check(legacy._batch_ready() and flow(legacy_client)._batch_ready(),"legacy wait completion is durable across restart")
	var peer_client: API = api("two-pause-owner")
	var peer_a: TrackLifecycle = flow(peer_client)
	var peer_b: TrackLifecycle = flow(peer_client)
	peer_a._pause_batch({"status":429,"retry_after":60}); peer_b._pause_batch({"status":429,"retry_after":90})
	check(DirAccess.get_files_at(peer_a._wait_root()).size() == 2,"independent peers publish immutable pause records")
	check(not peer_a._batch_ready(),"both pause records are observed")
	var expire_one: String = str(peer_a._batch_deadlines.keys()[0])
	peer_a._batch_deadlines[expire_one] = 0
	check(not peer_a._batch_ready() and not flow(peer_client)._batch_ready(),"expiring one nonce cannot clear the other peer's pause")
	var late_client: API = api("late-clock-owner")
	var late: TrackLifecycle = flow(late_client)
	late_client._sample_time(1800000000)
	late._pause_batch({"status":429,"retry_after":60})
	late_client._server_sample = 0
	check(not late._batch_ready(),"pause remains conservative without a sampled server clock")
	late_client._sample_time(1800000061)
	check(late._batch_ready(),"a later authoritative clock releases the elapsed server deadline")
	for status: int in [502,503,504]:
		var unavailable: TrackLifecycle = flow(api("unavailable-"+str(status)))
		unavailable._pause_batch({"status":status,"retry_after":5})
		check(not unavailable._batch_ready(),"service backpressure also pauses later publication calls")
	client = api("retry-owner")
	var retrying: TrackLifecycle = flow(client)
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json")).document
	document.id = TrackLibrary.unique_id()
	var path: String = retrying._path(document)
	var job := {"schema":"track-lifecycle-1","scope":retrying.scope(),"library_directory":retrying.library.directory,
		"fingerprint":"retry-fixture","upload_key":"upload-permanent","publish_key":"publish-permanent","ticket_key":"ticket-permanent",
		"state":"failed","created_at":1,"document":document,"vehicle":"compact","contract":{},"proof_file":"retry.proof.json",
		"publish_requested":true,"publish_workflow":2,"publication_id":"publication-fixture","remote":{"retryable":true}}
	check(retrying._save(path,job),"retry fixture committed")
	retrying.cloud._write(retrying._root().path_join("retry.proof.json"),{"fixture":"unchanged creator evidence"})
	var original: PackedByteArray = FileAccess.get_file_as_bytes(retrying._root().path_join("retry.proof.json"))
	await retrying.retry(document)
	check(client.calls.size() == 1 and client.calls[0].path.ends_with("/retry"),"explicit retry sends one request")
	check(not retrying._batch_ready(),"explicit retry 429 persists the shared pause")
	var saved: Dictionary = retrying.status_for(document)
	check(saved.has("publication_retry_key") and saved.upload_key == "upload-permanent","rejected retry retains both operation identities")
	await retrying.retry(document)
	check(client.calls.size() == 1,"repeated explicit retry obeys the pause")
	var restarted: TrackLifecycle = flow(client)
	await restarted.retry(document)
	check(client.calls.size() == 1,"explicit retry remains paused after restart")
	check(not await restarted.request_publish(document) and client.calls.size() == 1,"explicit Publish does not issue bootstrap or upload calls during the pause")
	check(FileAccess.get_file_as_bytes(retrying._root().path_join("retry.proof.json")) == original,"explicit retry failures retain exact creator evidence")
	var vault: RefCounted = preload("res://backend/session_vault.gd").new()
	for invalid: String in ["", "%%%%", "AAAA=", "A===", "AAAA\nAAAA", "AB==", "x".repeat(90001)]:
		check(vault.open("BMT-SESSION-1\n"+invalid,"fixture-context").is_empty(),"malformed encrypted-save framing is rejected quietly")
	var lock := RotationLock.new(folder.path_join("corrupt-lock"))
	DirAccess.make_dir_absolute(lock.path)
	var owner := FileAccess.open(lock.path.path_join("owner.json"),FileAccess.WRITE)
	owner.store_string("{invalid"); owner.close()
	check(lock._owner().is_empty() and DirAccess.dir_exists_absolute(lock.path),"malformed lock ownership is preserved and parsed quietly")
	await real_process_pauses()
	for child: Node in root.get_children():
		if child != root.get_node_or_null("AudioWorld"): child.queue_free()
	await process_frame
	print("COMMUNICATION_FOLLOWUP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func real_process_pauses() -> void:
	var pids: Array[int] = []
	var notices: Array[String] = []
	for index: int in range(2):
		var notify: String = folder.path_join("publication-child-"+str(index)+".json")
		notices.append(notify)
		pids.append(OS.create_process(OS.get_executable_path(),PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"--script","res://tests/publication_pause_worker.gd","--","--folder="+folder,"--notify="+notify])))
	var began: int = Time.get_ticks_msec()
	while not notices.all(func(path: String) -> bool: return FileAccess.file_exists(path+".ready")):
		if Time.get_ticks_msec()-began > 12000: check(false,"publication child readiness deadline"); return
		await process_frame
	check(pids[0] > 0 and pids[1] > 0 and pids[0] != pids[1],"two actual publication writer processes started")
	var go := FileAccess.open(folder.path_join("publication-go"),FileAccess.WRITE)
	go.store_string("go"); go.close()
	while not notices.all(func(path: String) -> bool: return FileAccess.file_exists(path)):
		if Time.get_ticks_msec()-began > 18000: check(false,"publication child result deadline"); return
		await process_frame
	var result_a: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(notices[0]))
	var result_b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(notices[1]))
	check(result_a.pid == pids[0] and result_b.pid == pids[1] and result_a.blocked and result_b.blocked,"each owned process enforces its shared-scope pause")
	check(result_a.root == result_b.root and DirAccess.get_files_at(str(result_a.root)).size() == 2,"simultaneous processes retain both immutable pause files")
	var parent: TrackLifecycle = flow(api("actual-process-pause-owner"))
	parent.cloud.client._sample_time(1800000000)
	check(not parent._batch_ready(),"parent observes both actual process pauses")
	parent.cloud.client._sample_time(1800000091)
	check(parent._batch_ready() and DirAccess.get_files_at(parent._wait_root()).is_empty(),"expired process pauses are retired without reviving on restart")
	while pids.any(func(pid: int) -> bool: return OS.is_process_running(pid)):
		if Time.get_ticks_msec()-began > 20000: check(false,"publication child teardown deadline"); return
		await process_frame
