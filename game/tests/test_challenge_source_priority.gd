extends SceneTree
## Real auth dispatcher and challenge adapter against held transport boundaries.
const Client = preload("res://backend/backend_client.gd")
const SOURCE = "/challenges/sources?version_id=00000000-0000-0000-0000-000000000001&vehicle_id=compact"
var checks: int = 0
var failures: int = 0

class API extends Client:
	signal release_upload
	signal release_read
	signal release_source
	var upload_started: bool = false
	var read_retry_started: bool = false
	var source_started: bool = false
	var hold_source: bool = false
	var expired: bool = true
	var switch_account: bool = false
	var refreshes: int = 0
	var source_calls: int = 0
	var requested: Array[String] = []
	func _send(path: String, _method: HTTPClient.Method, _payload: Dictionary, _auth: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		requested.append(path)
		if path == "/runs":
			upload_started = true
			await release_upload
			return {"ok":true,"status":202,"data":{},"error":""}
		if path == "/auth/refresh":
			refreshes += 1
			await get_tree().process_frame
			return {"ok":true,"status":200,"data":{"access_token":"fresh-access","refresh_token":"fresh-refresh","player":{"id":"fixture-player"}},"error":""}
		if path == "/me":
			if _access_token != "fresh-access": return {"ok":false,"status":401,"data":{},"error":"INVALID_SESSION"}
			read_retry_started = true
			await release_read
			return {"ok":true,"status":200,"data":{"id":"fixture-player"},"error":""}
		if path.begins_with("/challenges/sources?"):
			source_calls += 1
			if hold_source and not source_started:
				source_started = true
				await release_source
				return {"ok":false,"status":401,"data":{},"error":"INVALID_SESSION"}
			await get_tree().process_frame
			if expired and _access_token != "fresh-access": return {"ok":false,"status":401,"data":{},"error":"INVALID_SESSION"}
			if switch_account: clear_session()
			return {"ok":true,"status":200,"data":{"status":"verified","run_id":"fixture-run","ms":88110},"error":""}
		return {"ok":true,"status":200,"data":{},"error":""}

func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ",label)
func fixture() -> API:
	var api := API.new()
	root.add_child(api)
	api.configure("http://127.0.0.1:18181")
	api.player = {"id":"fixture-player"}
	api._access_token = "old-access"
	api._refresh_token = "r".repeat(64)
	return api
func upload(api: API, result: Dictionary) -> void:
	result.value = await api.request_api("/runs",HTTPClient.METHOD_POST,{},"upload-key",true)
	result.done = true
func source(api: API, result: Dictionary, ticket: String = "") -> void:
	var adapter := ChallengesClient.new()
	adapter.client = api
	root.add_child(adapter)
	var started: int = Time.get_ticks_usec()
	result.value = await adapter.source("00000000-0000-0000-0000-000000000001","compact",ticket)
	result.elapsed_ms = (Time.get_ticks_usec()-started)/1000.0
	result.done = true
	adapter.queue_free()
func read(api: API, result: Dictionary) -> void:
	result.value = await api.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	result.done = true
func observer(api: API, result: Dictionary) -> void:
	result.value = await api._renew_session(api._session_generation,"/other-observer",HTTPClient.METHOD_GET,{},"","old-access")
	result.done = true
func run() -> void:
	for expired: bool in [false,true]:
		var api := fixture()
		api.expired = expired
		var writing := {"done":false}
		upload(api,writing)
		while not api.upload_started: await process_frame
		var looking := {"done":false}
		var second := {"done":false}
		var started: int = Time.get_ticks_usec()
		source(api,looking)
		if expired: source(api,second,"00000000-0000-0000-0000-000000000002")
		for frame: int in range(25): await process_frame
		check(looking.done and not writing.done,"source lookup finishes before held upload; expired="+str(expired))
		if expired: check(second.done,"simultaneous exact-ticket lookup also finishes before held upload")
		check(api._busy,"lookup never releases the upload owner's lock")
		print("SOURCE_PRIORITY ",JSON.stringify({"expired":expired,"completed_before_release":looking.done,"elapsed_ms":looking.get("elapsed_ms"),"observation_ms":(Time.get_ticks_usec()-started)/1000.0}))
		api.release_upload.emit()
		while not writing.done or not looking.done or (expired and not second.done): await process_frame
		check(looking.value.status == "verified" and looking.value.ms == 88110,"lookup returns actual verified time")
		check(api.refreshes == (1 if expired else 0),"concurrent sources share one credential rotation")
		if expired: check(api.requested.count(SOURCE+"&ticket_id=00000000-0000-0000-0000-000000000002") == 2,"refresh keeps the exact completed-ticket query")
		check(not api._busy and not api._refresh_busy,"owners finish with both locks released")
		api.free()
	for changed: bool in [false,true]:
		var api := fixture()
		api.hold_source = true
		api.switch_account = changed
		var looking := {"done":false}
		source(api,looking)
		while not api.source_started: await process_frame
		var reading := {"done":false}
		read(api,reading)
		while not api.read_retry_started: await process_frame
		var observing := {"done":false}
		if not changed: observer(api,observing)
		api.release_source.emit()
		for frame: int in range(12): await process_frame
		check(looking.done and not reading.done,"already refreshed source bypasses held original read")
		check(api._busy and api._refresh_busy,"lookup preserves refresh and mutation ownership")
		if not changed: check(not observing.done,"unrelated reads keep their original renewal serialization")
		api.release_read.emit()
		while not looking.done or not reading.done: await process_frame
		if changed: check(looking.value.status == "unavailable" and not api.signed_in(),"account switch cannot expose an old verified time")
		else:
			while not observing.done: await process_frame
			check(looking.value.status == "verified" and api.refreshes == 1,"fresh access handles the source without a second renewal")
		check(not api._busy and not api._refresh_busy,"held read releases only its own locks")
		api.free()
	check(Client._independent_auth_request(SOURCE,HTTPClient.METHOD_GET),"only the exact source GET route joins race auth priority")
	for path: String in ["/challenges","/challenges/sources/other","/challenges/source","/runs"]:
		check(not Client._independent_auth_request(path,HTTPClient.METHOD_GET),"unrelated read remains serialized on renewal: "+path)
	check(not Client._independent_auth_request(SOURCE,HTTPClient.METHOD_POST),"source mutation is never granted priority")
	print("CHALLENGE_SOURCE_PRIORITY: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
