extends SceneTree
## Held upload plus real request dispatcher, without network or player writes.
const Client = preload("res://backend/backend_client.gd")
var checks: int = 0
var failures: int = 0
var ticket_done: bool = false
var upload_done: bool = false
var ticket_response: Dictionary = {}
var upload_response: Dictionary = {}

class API extends Client:
	signal release_upload
	var upload_started: bool = false
	var calls: Array[String] = []
	var keys: Array[String] = []
	var manifest: Dictionary = {}
	var mode: String = "normal"
	var refreshes: int = 0
	var rejected_compression: bool = false
	func _send(path: String, _method: HTTPClient.Method, _payload: Dictionary, _auth: bool, key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		calls.append(path)
		keys.append(key)
		if path == "/auth/refresh":
			refreshes += 1
			await get_tree().process_frame
			return {"ok":true,"status":200,"data":{"access_token":"replacement-access","refresh_token":"replacement-refresh","player":{"id":"fictional-player"}},"error":""}
		if path == "/runs":
			upload_started = true
			await release_upload
			return {"ok":true,"status":202,"data":{"run_id":"fictional-run","ticket_id":"fictional-old-ticket","status":"queued"},"error":""}
		await get_tree().process_frame
		if mode == "expired" and _access_token != "replacement-access": return {"ok":false,"status":401,"data":{},"error":"INVALID_SESSION"}
		if mode == "gzip" and not rejected_compression:
			rejected_compression = true
			return {"ok":false,"status":415,"data":{},"error":"UNSUPPORTED_ENCODING"}
		if mode == "account":
			clear_session()
		return {"ok":true,"status":201,"data":{"ticket_id":"fictional-fresh-ticket","manifest":manifest},"error":""}

func _initialize() -> void: call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures += 1; print("FAIL: ",label)

func request_ticket(api: API, path: String) -> void:
	ticket_response = await api.request_api(path,HTTPClient.METHOD_POST,{},"ticket-key",true)
	ticket_done = true

func request_upload(api: API) -> void:
	upload_response = await api.request_api("/runs",HTTPClient.METHOD_POST,{},"upload-key",true)
	upload_done = true

func fixture_api(fixture: Dictionary) -> API:
	var api := API.new()
	root.add_child(api)
	api.configure("http://127.0.0.1:18181")
	api._access_token = "fictional-access"
	api.player = {"id":"fictional-player"}
	api.manifest = TrackLifecycle._contract(fixture.document,"compact")
	api.manifest.laps = RaceRules.LAPS
	return api

func run() -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../backend/tests/fixtures/verified_oval.json"))
	for path: String in ["/run-tickets","/rivalry/fictional-group/tickets","/challenges/fictional-code/tickets"]:
		var api: API = fixture_api(fixture)
		ticket_done = false
		upload_done = false
		request_upload(api)
		while not api.upload_started: await process_frame
		var start: int = Time.get_ticks_usec()
		request_ticket(api,path)
		for frame: int in range(12): await process_frame
		check(ticket_done and not upload_done,path+" fresh race ticket completes while upload is held")
		check(api._busy,path+" ticket does not release another request's serialization lock")
		print("TICKET_PRIORITY route=",path.get_slice("/",1)," ticket_done=",ticket_done," elapsed_ms=",(Time.get_ticks_usec()-start)/1000.0)
		api.release_upload.emit()
		while not upload_done or not ticket_done: await process_frame
		check(ticket_response.ok and upload_response.ok,path+" both operations survive (ticket="+str(ticket_response.get("error"))+", upload="+str(upload_response.get("error"))+")")
		check(api.keys == ["upload-key","ticket-key"],path+" request keys stay distinct and stable")
		check(not api._busy,path+" upload owns final lock release")
		api.free()
	for mode: String in ["expired","gzip","account"]:
		var api: API = fixture_api(fixture)
		api.mode = mode
		api._refresh_token = "r".repeat(64)
		var result: Dictionary = await api.request_api("/run-tickets",HTTPClient.METHOD_POST,{"version_id":"fictional-version"},"same-ticket-key",true)
		if mode == "expired":
			check(result.ok and api.refreshes == 1 and api.signed_in(),"expired session rotates once then authorizes the requested race")
			check(api.keys[0] == "same-ticket-key" and api.keys[-1] == "same-ticket-key","refresh retry retains the exact ticket operation key")
		elif mode == "gzip":
			check(result.ok and api._disable_gzip and api.keys == ["same-ticket-key","same-ticket-key"],"compression fallback preserves ticket identity")
		else: check(not result.ok and result.error == "ACCOUNT_CHANGED","account change rejects a stale ticket response")
		check(not api._busy,mode+" leaves the credential lock released")
		api.free()
	var rotating: API = fixture_api(fixture)
	rotating.mode = "expired"
	rotating._refresh_token = "r".repeat(64)
	ticket_done = false
	request_ticket(rotating,"/run-tickets")
	var second: Dictionary = await rotating.request_api("/rivalry/fictional-group/tickets",HTTPClient.METHOD_POST,{},"second-key",true)
	while not ticket_done: await process_frame
	check(second.ok and ticket_response.ok and rotating.refreshes == 1,"simultaneous expired tickets share one credential rotation")
	check(rotating.keys.count("ticket-key") == 2 and rotating.keys.count("second-key") == 2,"each simultaneous retry keeps its own original ticket key")
	check(not rotating._busy,"concurrent ticket refresh leaves no held lock")
	rotating.free()
	check(not Client._race_ticket_path("/runs") and not Client._race_ticket_path("/challenges/code/rematch") and not Client._race_ticket_path("/rivalry/tickets/id/result"),"priority is restricted to actual race ticket operations")
	print("RACE_TICKET_PRIORITY checks=",checks," failures=",failures)
	quit(1 if failures else 0)
