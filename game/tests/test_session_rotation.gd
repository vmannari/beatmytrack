extends SceneTree
## Fictional sessions and isolated files exercise shared renewal and its fences.
const Client = preload("res://backend/backend_client.gd")
const Lock = preload("res://backend/session_rotation_lock.gd")
var checks: int = 0
var failures: int = 0
var folder: String

class Service extends RefCounted:
	var access: String = "expired"
	var refresh: String = "fixture-refresh-00000000000000000000"
	var rotations: int = 0
	var reuses: int = 0
	var reads: int = 0
	var offline_retry: bool = false

class SimulatedClient extends Client:
	var service: Service
	var change_login: Callable
	var change_login_on_reuse: Callable
	var sign_out_during_refresh: bool = false
	func _send(path: String, _method: HTTPClient.Method, payload: Dictionary, authorized: bool, _key: String = "", _headers: PackedStringArray = [], _owner: int = 0) -> Dictionary:
		var sent_access: String = _access_token
		await get_tree().create_timer(0.01).timeout
		if path == "/auth/refresh":
			if change_login.is_valid(): change_login.call()
			if sign_out_during_refresh: clear_session()
			if str(payload.refresh_token) != service.refresh:
				service.reuses += 1
				return _failure("REFRESH_REUSE_DETECTED",401)
			service.rotations += 1
			service.access = "fixture-access-"+str(service.rotations)
			service.refresh = "fixture-refresh-"+str(service.rotations).pad_zeros(32)
			return {"ok":true,"status":200,"error":"","data":{"access_token":service.access,"refresh_token":service.refresh,"player":{"id":"rotation-player","display_name":"Rotation driver"}}}
		if authorized and (sent_access != service.access or sent_access == "expired"): return _failure("INVALID_SESSION",401)
		if authorized and change_login_on_reuse.is_valid(): change_login_on_reuse.call()
		if service.offline_retry: return _failure("NETWORK_ERROR")
		service.reads += 1
		if path == "/me": return {"ok":true,"status":200,"error":"","data":{"id":"rotation-player"}}
		if path == "/runs": return {"ok":true,"status":202,"error":"","data":{"run_id":"rotation-run","status":"queued"}}
		return {"ok":true,"status":200,"error":"","data":{}}

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: "+message)

func client(service: Service, suffix: String, existing: SimulatedClient = null) -> SimulatedClient:
	var result := SimulatedClient.new()
	root.add_child(result)
	result.configure("http://127.0.0.1:18181")
	result.service = service
	result.session_path = folder.path_join(suffix+".cfg") if existing == null else existing.session_path
	if existing == null:
		result._access_token = "expired"
		result._refresh_token = service.refresh
		result.player = {"id":"rotation-player","display_name":"Rotation driver"}
		result._save_session()
	else:
		result._access_token = existing._access_token
		result._refresh_token = existing._refresh_token
		result._login_id = existing._login_id
		result.player = existing.player.duplicate(true)
	return result

func run() -> void:
	folder = "user://rotation_test_"+TrackLibrary.unique_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var service := Service.new()
	var first: SimulatedClient = client(service,"shared")
	var second: SimulatedClient = client(service,"shared",first)
	var responses: Array[Dictionary] = []
	collect(first,"/rivalry/result",HTTPClient.METHOD_GET,responses)
	collect(second,"/runs",HTTPClient.METHOD_POST,responses)
	while responses.size() < 2: await process_frame
	check(responses.all(func(value: Dictionary) -> bool: return value.ok),"simultaneous readers/writers sharing a save both succeed")
	check(service.reuses == 0 and first.signed_in() and second.signed_in(),"shared renewal never replays a consumed refresh or logs out either client")
	check(service.rotations == 1,"shared clients reuse the issued access token instead of rotating each other out")
	for attempt: int in range(8):
		await first.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
		await second.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	check(service.rotations == 1,"alternating instances do not cause ongoing credential ping-pong")
	check(not DirAccess.dir_exists_absolute(first.session_path+".rotation"),"shared request lease is released")
	first.queue_free(); second.queue_free()
	await process_frame

	service = Service.new()
	first = client(service,"cached-expired")
	var saved := ConfigFile.new()
	first._load_saved_config(saved)
	saved.set_value("session","access_token","another-expired-credential")
	first._write_saved_config(saved)
	var expired: Dictionary = await first.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	check(expired.ok and service.rotations == 1,"an expired saved access credential falls back to one authenticated renewal")
	first.queue_free(); await process_frame

	service = Service.new()
	first = client(service,"reuse-login-fence")
	second = client(service,"reuse-login-fence",first)
	await first.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	second.change_login_on_reuse = func() -> void:
		first._login_id = "different-explicit-login"
		first._save_session()
	var fenced: Dictionary = await second.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	check(fenced.error == "ACCOUNT_CHANGED" and not second.signed_in(),"cached credential reuse remains fenced against an explicit login during delivery")
	check(first.has_saved_session() and not FileAccess.file_exists(first.session_path+".signed_out"),"reuse fence preserves the newer saved login")
	first.queue_free(); second.queue_free(); await process_frame

	service = Service.new()
	first = client(service,"same-client")
	responses.clear()
	collect(first,"/rivalry/result",HTTPClient.METHOD_GET,responses)
	collect(first,"/runs",HTTPClient.METHOD_POST,responses)
	while responses.size() < 2: await process_frame
	check(responses.all(func(value: Dictionary) -> bool: return value.ok) and service.rotations == 1,"one client renews once for overlapping upload/result polling")
	first.queue_free(); await process_frame

	service = Service.new()
	first = client(service,"transport")
	service.offline_retry = true
	var failed: Dictionary = await first.request_api("/runs",HTTPClient.METHOD_POST,{},"same-mutation-key",true)
	check(not failed.ok and first.signed_in() and first.has_saved_session(),"an ambiguous upload response after successful refresh retains authentication")
	first.queue_free(); await process_frame

	service = Service.new()
	first = client(service,"changed-login")
	second = client(service,"changed-login",first)
	first.change_login = func() -> void:
		second._login_id = "a-new-explicit-login"
		second._save_session()
	failed = await first.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	check(failed.error == "ACCOUNT_CHANGED" and not first.signed_in(),"a different explicit login ends only the stale in-memory session")
	check(second.has_saved_session() and not FileAccess.file_exists(second.session_path+".signed_out"),"late renewal cannot erase or fence another saved login")
	first.queue_free(); second.queue_free(); await process_frame

	service = Service.new()
	first = client(service,"changed-startup")
	second = client(service,"changed-startup",first)
	first.change_login = func() -> void:
		second._login_id = "another-explicit-startup-login"
		second._save_session()
	failed = await first.restore_session()
	check(failed.error == "ACCOUNT_CHANGED" and not first.signed_in() and second.has_saved_session(),"a late startup restore preserves another explicit saved login")
	first.queue_free(); second.queue_free(); await process_frame

	service = Service.new()
	first = client(service,"sign-out")
	first.sign_out_during_refresh = true
	failed = await first.request_api("/me",HTTPClient.METHOD_GET,{},"",true)
	check(failed.error == "ACCOUNT_CHANGED" and not first.signed_in() and not first.has_saved_session(),"sign-out while renewing cannot be resurrected")
	first.queue_free(); await process_frame

	var lock := Lock.new(folder.path_join("crash.cfg"))
	DirAccess.make_dir_absolute(lock.path)
	var dead := FileAccess.open(lock.path.path_join("owner.json"),FileAccess.WRITE)
	var abandoned_nonce: String = "a".repeat(48)
	dead.store_string(JSON.stringify({"pid":2147483647,"nonce":abandoned_nonce}))
	dead.close()
	check(await lock.acquire(self) == OK,"a dead process's lock can be recovered")
	check(DirAccess.dir_exists_absolute(lock.path+".abandoned."+abandoned_nonce),"dead lock retains a tombstone against stale observers")
	lock.release()
	check(not DirAccess.dir_exists_absolute(lock.path),"recovered lease releases its own exact paths")
	print("SESSION_ROTATION: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func collect(value: SimulatedClient, path: String, method: HTTPClient.Method, responses: Array[Dictionary]) -> void:
	responses.append(await value.request_api(path,method,{},"stable-key" if method == HTTPClient.METHOD_POST else "",true))
