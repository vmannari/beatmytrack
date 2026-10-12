extends Node
signal identity_changed
## Optional online adapter. The local game and canonical step never depend on it.
## Browser sign-in and UI live in account_controller.gd. Only the rotating refresh token is persisted in the private application directory.
const MAX_RESPONSE_BYTES: int = 8388608
var _base_url: String = ""
var _access_token: String = ""
var _refresh_token: String = ""
var _login_id: String = ""
var _busy: bool = false
var _session_generation: int = 0
var player: Dictionary = {}
# Empty disables persistence for standalone adapters/tests. Never include in exports.
var session_path: String = ""
var persistence_error: bool = false
var _public_reads: Array[HTTPRequest] = []
var _rotation_locks: Array[RefCounted] = []
var _read_cache: Dictionary = {}
var _encoding_threads: Array[Thread] = []
var _race_status_cache: Dictionary = {}
var _capabilities: Dictionary = {}
var _server_sample: int = 0
var _server_sample_msec: int = 0
var _disable_gzip: bool = false
var _disable_packed: bool = false
var _refresh_request_id: String = ""
var resume_recovery: Node

func _ready() -> void:
	resume_recovery = preload("res://backend/resume_recovery.gd").new()
	resume_recovery.client = self
	add_child(resume_recovery)

func _exit_tree() -> void:
	for thread: Thread in _encoding_threads:
		if thread.is_started(): thread.wait_to_finish()
	for lock: RefCounted in _rotation_locks: lock.release()
	_rotation_locks.clear()

func cancel_public_reads(owner_id: int) -> void:
	for request: HTTPRequest in _public_reads.duplicate():
		if is_instance_valid(request) and int(request.get_meta("owner_id",0)) == owner_id:
			request.cancel_request()
			request.set_meta("cancelled",true)
			request.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED,0,PackedStringArray(),PackedByteArray())

func request_public(path: String, owner_id: int) -> Dictionary:
	return await _send(path,HTTPClient.METHOD_GET,{},false,"",PackedStringArray(),owner_id)

func base_url() -> String:
	return _base_url

func auth_busy() -> bool:
	return _busy

static func refresh_retry_safe(response: Dictionary) -> bool:
	return bool(response.get("not_delivered",false)) or (bool(response.get("recoverable_refresh",false)) and (int(response.get("status",0)) in [0,429,500,502,503,504] or str(response.get("error","")) in ["INVALID_INPUT","INVALID_RESPONSE"])) or (int(response.get("status",0)) == 429 and str(response.get("error","")) == "RATE_LIMITED") or (int(response.get("status",0)) == 503 and str(response.get("error","")) == "REQUEST_VALIDATION_BUSY")

func configure(base_url: String) -> Error:
	if _busy: return ERR_BUSY
	_capabilities.clear()
	_server_sample = 0
	_disable_gzip = false
	_disable_packed = false
	var url: String = base_url.trim_suffix("/")
	if url.is_empty():
		clear_session()
		_base_url = ""
		return OK
	# Bearer credentials require TLS except explicit local development loopback.
	var loopback: bool = url.begins_with("http://127.0.0.1:") or url.begins_with("http://localhost:")
	if not (url.begins_with("https://") or loopback) or "@" in url or "?" in url or "#" in url or "\n" in url or "\r" in url:
		return ERR_INVALID_PARAMETER
	if not _base_url.is_empty(): clear_session()
	_base_url = url
	return OK

func clear_session(preserve_saved: bool = false) -> void:
	_session_generation += 1
	_read_cache.clear()
	_race_status_cache.clear()
	persistence_error = false
	if not preserve_saved and not session_path.is_empty() and (not _access_token.is_empty() or FileAccess.file_exists(session_path)):
		# A durable sign-out fence also protects restarts if an open file cannot
		# be removed on this platform. Only a later successful sign-in removes it.
		var fence := FileAccess.open(session_path+".signed_out",FileAccess.WRITE)
		if fence == null: persistence_error = true
		else:
			fence.store_string("signed_out")
			fence.flush()
			persistence_error = fence.get_error() != OK
			fence.close()
	if not preserve_saved: _forget_saved_session()
	_access_token = ""
	_refresh_token = ""
	_refresh_request_id = ""
	_login_id = ""
	player = {}
	identity_changed.emit()

func _forget_saved_session() -> void:
	if session_path.is_empty(): return
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(session_path + suffix):
			if DirAccess.remove_absolute(session_path + suffix) != OK: persistence_error = true

func _save_session() -> void:
	if session_path.is_empty(): return
	if _login_id.is_empty(): _login_id = new_idempotency_key()
	var config := ConfigFile.new()
	config.set_value("session", "url", _base_url)
	config.set_value("session", "refresh_token", _refresh_token)
	config.set_value("session", "login_id", _login_id)
	config.set_value("session", "player_id", str(player.get("id","")))
	if not _refresh_request_id.is_empty(): config.set_value("session","refresh_request_id",_refresh_request_id)
	var temporary: String = session_path + ".tmp"
	persistence_error = config.save(temporary) != OK
	if not persistence_error:
		persistence_error = DirAccess.rename_absolute(temporary, session_path) != OK
	if not persistence_error and FileAccess.file_exists(session_path+".signed_out"):
		persistence_error = DirAccess.remove_absolute(session_path+".signed_out") != OK
	# A failed replacement must preserve the previous durable recovery operation.

func has_saved_session() -> bool:
	return not session_path.is_empty() and not FileAccess.file_exists(session_path+".signed_out") and FileAccess.file_exists(session_path)

func discard_signed_out_session() -> void:
	if not session_path.is_empty() and FileAccess.file_exists(session_path+".signed_out"):
		_forget_saved_session()

func restore_session() -> Dictionary:
	if _busy: return _failure("BUSY")
	var config := ConfigFile.new()
	if not has_saved_session() or config.load(session_path) != OK:
		_forget_saved_session()
		return _failure("SIGN_IN_REQUIRED")
	if str(config.get_value("session", "url", "")) != _base_url:
		clear_session()
		return _failure("SIGN_IN_REQUIRED")
	var token: String = str(config.get_value("session", "refresh_token", ""))
	if token.is_empty():
		clear_session()
		return _failure("SIGN_IN_REQUIRED")
	_busy = true
	# Retain credentials only when transport proves the request was never delivered.
	var generation: int = _session_generation
	_refresh_token = token
	_login_id = _stored_login_id(config)
	var response: Dictionary = await _renew_session(generation)
	if generation != _session_generation:
		_busy = false
		return _failure("ACCOUNT_CHANGED")
	if not response.ok and not refresh_retry_safe(response): clear_session()
	_busy = false
	return response

static func _stored_login_id(config: ConfigFile) -> String:
	# Existing saves gain this metadata after their first successful rotation.
	return str(config.get_value("session","login_id","legacy-"+str(config.get_value("session","refresh_token","")).sha256_text()))

func _renew_session(generation: int, path: String = "", method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, key: String = "", used_access: String = "") -> Dictionary:
	var lock := preload("res://backend/session_rotation_lock.gd").new(session_path)
	_rotation_locks.append(lock)
	var acquired: Error = await lock.acquire(get_tree())
	if acquired != OK:
		_rotation_locks.erase(lock)
		var failed: Dictionary = _failure("SESSION_ROTATION_BUSY")
		failed.not_delivered = true
		return failed
	var response: Dictionary = await _renew_locked(generation,path,method,payload,key,used_access)
	lock.release()
	_rotation_locks.erase(lock)
	return response

func _renew_locked(generation: int, path: String, method: HTTPClient.Method, payload: Dictionary, key: String, used_access: String) -> Dictionary:
	if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if not path.is_empty() and _access_token != used_access:
		# An earlier request in this client already renewed while we waited.
		var retried: Dictionary = _checked(await _send(path,method,payload,true,key),path,method)
		if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
		if int(retried.status) != 401: return retried
	var expected_player: String = str(player.get("id",""))
	var config := ConfigFile.new()
	if not session_path.is_empty():
		if not has_saved_session() or config.load(session_path) != OK:
			if FileAccess.file_exists(session_path+".signed_out"):
				clear_session(true)
				return _failure("ACCOUNT_CHANGED")
			var failed: Dictionary = _failure("SESSION_STORAGE_ERROR")
			failed.not_delivered = true
			return failed
		var saved_player: String = str(config.get_value("session","player_id",""))
		if str(config.get_value("session","url","")) != _base_url or _stored_login_id(config) != _login_id or (not expected_player.is_empty() and not saved_player.is_empty() and expected_player != saved_player):
			# Another explicit sign-in is a different session, even for the same
			# player. Leave that saved session intact; never silently adopt it.
			clear_session(true)
			return _failure("ACCOUNT_CHANGED")
		_refresh_token = str(config.get_value("session","refresh_token",""))
		_refresh_request_id = str(config.get_value("session","refresh_request_id",""))
		if expected_player.is_empty(): expected_player = saved_player
	var supports_recovery: bool = not _refresh_request_id.is_empty() or int(_capabilities.get("refresh_recovery_seconds",0)) > 0
	var body: Dictionary = {"refresh_token":_refresh_token}
	if supports_recovery:
		if _refresh_request_id.is_empty(): _refresh_request_id = Crypto.new().generate_random_bytes(24).hex_encode()
		body.refresh_request_id = _refresh_request_id
		if not session_path.is_empty():
			config.set_value("session","refresh_request_id",_refresh_request_id)
			if config.save(session_path+".tmp") != OK or DirAccess.rename_absolute(session_path+".tmp",session_path) != OK:
				var failure: Dictionary = _failure("SESSION_STORAGE_ERROR")
				failure.not_delivered = true
				return failure
	var refresh: Dictionary = _checked(await _send("/auth/refresh",HTTPClient.METHOD_POST,body,false),"/auth/refresh",HTTPClient.METHOD_POST)
	if supports_recovery and not refresh.ok: refresh.recoverable_refresh = true
	if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if not session_path.is_empty():
		var current := ConfigFile.new()
		if not has_saved_session() or current.load(session_path) != OK or _stored_login_id(current) != _login_id:
			clear_session(true)
			return _failure("ACCOUNT_CHANGED")
	var returned_player: Variant = refresh.data.get("player",{})
	if refresh.ok and returned_player is Dictionary and not expected_player.is_empty() and str(returned_player.get("id","")) != expected_player:
		clear_session(true)
		return _failure("ACCOUNT_CHANGED")
	refresh = _remember(refresh,generation)
	if not refresh.ok:
		refresh.refresh_failed = true
		return refresh
	if path.is_empty(): return refresh
	# Keep the shared lock through this retry: another process cannot consume
	# the new access credential before the server accepts the original request.
	var response: Dictionary = _checked(await _send(path,method,payload,true,key),path,method)
	if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	return response

func signed_in() -> bool:
	return not _access_token.is_empty()

static func new_idempotency_key(unix_time: int = 0) -> String:
	var random: String = Crypto.new().generate_random_bytes(24).hex_encode()
	return "v2."+str(unix_time)+"."+random if unix_time > 0 else "op."+random

func server_now() -> int:
	return _server_sample+maxi(0,Time.get_ticks_msec()-_server_sample_msec)/1000 if _server_sample > 0 else 0

func new_operation_key() -> String:
	return new_idempotency_key(server_now())

func _sample_time(unix_time: int) -> void:
	if unix_time < 1000000000 or unix_time > 9999999999: return
	_server_sample = unix_time
	_server_sample_msec = Time.get_ticks_msec()

func _failure(code: String, status: int = 0) -> Dictionary:
	return {"ok":false,"status":status,"error":code,"data":{}}

static func _encode_request(payload: Dictionary, allow_compression: bool = true) -> Dictionary:
	var body: PackedByteArray = JSON.stringify(payload).to_utf8_buffer()
	if body.size() > MAX_RESPONSE_BYTES: return {"too_large":true}
	if body.size() < 1024 or not allow_compression: return {"body":body,"compressed":false}
	var compressed: PackedByteArray = body.compress(FileAccess.COMPRESSION_GZIP)
	return {"body":compressed if compressed.size() < body.size() else body,"compressed":compressed.size() < body.size()}

static func _decode_response(bytes: PackedByteArray, cacheable: bool = false) -> Dictionary:
	var body: String = bytes.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(body)
	return {"parsed":parsed,"body":body,"cache_data":parsed.duplicate(true) if cacheable and parsed is Dictionary else {}}

func remember_run(value: Dictionary) -> void:
	if not value.has_all(["ticket_id","status"]): return
	_race_status_cache[str(value.ticket_id)] = {"data":value,"at":Time.get_ticks_msec()}
	while _race_status_cache.size() > 32: _race_status_cache.erase(_race_status_cache.keys()[0])

func recent_run(ticket_id: String) -> Dictionary:
	var cached: Dictionary = _race_status_cache.get(ticket_id,{})
	return cached.get("data",{}) if Time.get_ticks_msec()-int(cached.get("at",-10000)) < 3000 else {}

func _background(work: Callable) -> Variant:
	var thread := Thread.new()
	if thread.start(work) != OK: return null
	_encoding_threads.append(thread)
	while thread.is_alive(): await get_tree().process_frame
	_encoding_threads.erase(thread)
	return thread.wait_to_finish()

func _send(path: String, method: HTTPClient.Method, payload: Dictionary, authorized: bool, idempotency_key: String = "", extra_headers: PackedStringArray = [], owner_id: int = 0) -> Dictionary:
	if _base_url.is_empty(): return _failure("NOT_CONFIGURED")
	if not path.begins_with("/") or path.begins_with("//") or "\n" in path or "\r" in path: return _failure("INVALID_PATH")
	if authorized and _access_token.is_empty(): return _failure("SIGN_IN_REQUIRED")
	var headers := PackedStringArray(["Accept: application/json","Content-Type: application/json"])
	if authorized: headers.append("Authorization: Bearer "+_access_token)
	if not idempotency_key.is_empty():
		if idempotency_key.length() > 128 or "\n" in idempotency_key or "\r" in idempotency_key: return _failure("INVALID_IDEMPOTENCY_KEY")
		headers.append("Idempotency-Key: "+idempotency_key)
	headers.append_array(extra_headers)
	var cache_key: String = _base_url+"/"+str(_session_generation)+path
	if method == HTTPClient.METHOD_GET and _read_cache.has(cache_key): headers.append("If-None-Match: "+str(_read_cache[cache_key].tag))
	var origin: String = _base_url
	var generation: int = _session_generation
	var packet: Variant = {"body":PackedByteArray(),"compressed":false} if method == HTTPClient.METHOD_GET else await _background(_encode_request.bind(payload,not _disable_gzip and "gzip" in _capabilities.get("upload_encodings",[])))
	if not packet is Dictionary: return _failure("REQUEST_ENCODING_FAILED")
	if packet.get("too_large",false): return _failure("REQUEST_TOO_LARGE")
	if origin != _base_url or (authorized and generation != _session_generation): return _failure("ACCOUNT_CHANGED")
	if packet.compressed: headers.append("Content-Encoding: gzip")
	var request := HTTPRequest.new()
	request.use_threads = true
	request.timeout = 2.0 if "/ghosts/" in path else 30.0
	request.body_size_limit = MAX_RESPONSE_BYTES
	request.max_redirects = 0 # Never forward credentials to a redirect target.
	add_child(request)
	var start: Error = request.request_raw(_base_url+"/v1"+path,headers,method,packet.body)
	if start != OK:
		request.queue_free()
		var failed: Dictionary = _failure("REQUEST_START_FAILED")
		failed.not_delivered = true
		return failed
	if method == HTTPClient.METHOD_GET and owner_id != 0:
		request.set_meta("owner_id",owner_id)
		_public_reads.append(request)
	var completed: Array = await request.request_completed
	_public_reads.erase(request)
	var cancelled: bool = bool(request.get_meta("cancelled",false))
	request.queue_free()
	if cancelled or origin != _base_url: return _failure("CANCELLED")
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS:
		var failed: Dictionary = _failure("NETWORK_ERROR")
		failed.transport_result = int(completed[0])
		failed.not_delivered = int(completed[0]) in [HTTPRequest.RESULT_CANT_RESOLVE,HTTPRequest.RESULT_CANT_CONNECT,HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR]
		return failed
	var status: int = int(completed[1])
	var tag: String = ""
	var server_time: int = 0
	for header: String in completed[2]:
		if header.to_lower().begins_with("etag:"): tag = header.substr(5).strip_edges()
		elif header.to_lower().begins_with("x-server-time:"): server_time = int(header.get_slice(":",1).strip_edges())
	if server_time > 0: _sample_time(server_time)
	if status == 304 and _read_cache.has(cache_key):
		var cached: Dictionary = _read_cache[cache_key].data.duplicate(true)
		if server_time > 0 and cached.has("server_now"):
			cached.server_now = server_time
			cached.remaining_seconds = maxi(0,int(cached.ends_at)-server_time)
		return {"ok":true,"status":200,"data":cached,"body":str(_read_cache[cache_key].get("body","")),"error":"","not_modified":true}
	var bytes: PackedByteArray = completed[3]
	var cacheable: bool = method == HTTPClient.METHOD_GET and status == 200 and not tag.is_empty() and bytes.size() <= 524288
	var decoded: Variant = {"parsed":{},"body":"","cache_data":{}} if bytes.is_empty() else await _background(_decode_response.bind(bytes,cacheable))
	if not decoded is Dictionary: return _failure("INVALID_RESPONSE",status)
	var parsed: Variant = decoded.parsed
	if origin != _base_url: return _failure("CANCELLED")
	if authorized and generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if not parsed is Dictionary: return _failure("INVALID_RESPONSE",status)
	if status >= 200 and status < 300 and not valid_response(path,method,parsed): return _failure("INVALID_RESPONSE",502)
	if path == "/bootstrap" and _whole(parsed.get("server_now",0)): _sample_time(int(parsed.get("server_now",0)))
	if path == "/bootstrap" and status == 200: _capabilities = parsed.duplicate(true)
	if authorized and generation == _session_generation and status >= 200 and status < 300:
		if parsed.has("ticket_id") and parsed.has("status"): remember_run(parsed)
		if path.begins_with("/runs/status"):
			for item: Dictionary in parsed.get("items",[]): remember_run(item)
	if method == HTTPClient.METHOD_GET and status == 200 and not tag.is_empty() and bytes.size() <= 524288 and origin == _base_url and generation == _session_generation:
		_read_cache.erase(cache_key)
		_read_cache[cache_key] = {"tag":tag,"data":decoded.cache_data,"body":decoded.body,"bytes":bytes.size()}
		while _read_cache.size() > 16: _read_cache.erase(_read_cache.keys()[0])
		var cache_bytes: int = 0
		for entry: Dictionary in _read_cache.values(): cache_bytes += int(entry.bytes)
		while cache_bytes > 2097152:
			var oldest: String = str(_read_cache.keys()[0])
			cache_bytes -= int(_read_cache[oldest].bytes)
			_read_cache.erase(oldest)
	var retry_after: int = 0
	for header: String in completed[2]:
		if header.to_lower().begins_with("retry-after:"): retry_after = clampi(int(header.get_slice(":",1).strip_edges()),1,60)
	return {"ok":status >= 200 and status < 300,"status":status,"data":parsed,"body":decoded.body,"retry_after":retry_after,"error":"" if status >= 200 and status < 300 else str(parsed.get("detail","HTTP_ERROR"))}

func _remember(response: Dictionary, generation: int = -1) -> Dictionary:
	if generation != -1 and generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if not response.ok: return response
	var data: Dictionary = response.data
	if not data.get("access_token") is String or not data.get("refresh_token") is String or not data.get("player") is Dictionary:
		clear_session()
		return _failure("INVALID_SESSION_RESPONSE")
	_access_token = data.access_token
	_refresh_token = data.refresh_token
	_refresh_request_id = ""
	var previous_player: Dictionary = player
	player = data.player.duplicate(true)
	_save_session()
	if player != previous_player: identity_changed.emit()
	# Callers receive player/expiry, never copies of bearer credentials.
	var safe: Dictionary = data.duplicate(true)
	safe.erase("access_token")
	safe.erase("refresh_token")
	response.data = safe
	response.erase("body")
	return response

func google_challenge() -> Dictionary:
	return await request_api("/auth/google/challenge",HTTPClient.METHOD_POST)

func developer_login(development_key: String) -> Dictionary:
	if _busy: return _failure("BUSY")
	if "\n" in development_key or "\r" in development_key: return _failure("INVALID_DEVELOPMENT_KEY")
	_busy = true
	clear_session()
	var generation: int = _session_generation
	var response: Dictionary = _remember(await _send("/auth/developer",HTTPClient.METHOD_POST,{},false,"",PackedStringArray(["X-Dev-Auth-Key: "+development_key])),generation)
	_busy = false
	return response

func poll_google(poll_token: String) -> Dictionary:
	if _busy: return _failure("BUSY")
	_busy = true
	var generation: int = _session_generation
	var response: Dictionary = await _send("/auth/google/browser/poll",HTTPClient.METHOD_POST,{"token":poll_token},false)
	if response.ok and response.data.get("status", "") != "pending": response = _remember(response,generation)
	_busy = false
	return response

func google_login(id_token: String, challenge_id: String, display_name: String = "Racer") -> Dictionary:
	if _busy: return _failure("BUSY")
	_busy = true
	clear_session()
	var generation: int = _session_generation
	var response: Dictionary = _remember(await _send("/auth/google",HTTPClient.METHOD_POST,{"id_token":id_token,"challenge_id":challenge_id,"display_name":display_name},false),generation)
	_busy = false
	return response

func development_login(subject: String, display_name: String, development_key: String) -> Dictionary:
	if _busy: return _failure("BUSY")
	if "\n" in development_key or "\r" in development_key: return _failure("INVALID_DEVELOPMENT_KEY")
	_busy = true
	clear_session()
	var generation: int = _session_generation
	var response: Dictionary = _remember(await _send("/auth/development",HTTPClient.METHOD_POST,{"subject":subject,"display_name":display_name},false,"",PackedStringArray(["X-Dev-Auth-Key: "+development_key])),generation)
	_busy = false
	return response

func request_api(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, idempotency_key: String = "", authenticated: bool = false) -> Dictionary:
	# Public reads need no session rotation and must not block racing or sign-in.
	if not authenticated and method == HTTPClient.METHOD_GET:
		return _checked(await _send(path,method,payload,false,idempotency_key),path,method)
	if authenticated and method == HTTPClient.METHOD_GET:
		return await _authenticated_read(path)
	var identity: String = str(player.get("id",""))
	var generation: int = _session_generation
	while _busy: await get_tree().process_frame
	if authenticated and (str(player.get("id","")) != identity or generation != _session_generation): return _failure("ACCOUNT_CHANGED")
	_busy = true
	var used_access: String = _access_token
	var response: Dictionary = _checked(await _send(path,method,payload,authenticated,idempotency_key),path,method)
	if response.status == 415 and not _disable_gzip:
		_disable_gzip = true
		response = _checked(await _send(path,method,payload,authenticated,idempotency_key),path,method)
	if authenticated and (str(player.get("id","")) != identity or generation != _session_generation):
		_busy = false
		return _failure("ACCOUNT_CHANGED")
	if authenticated and response.status == 401 and not _refresh_token.is_empty():
		response = await _renew_session(generation,path,method,payload,idempotency_key,used_access)
		if generation != _session_generation:
			_busy = false
			return _failure("ACCOUNT_CHANGED")
		if response.status == 401 or (response.get("refresh_failed",false) and not refresh_retry_safe(response)): clear_session()
	elif authenticated and response.status == 401:
		clear_session()
	_busy = false
	return response

func _authenticated_read(path: String) -> Dictionary:
	var identity: String = str(player.get("id",""))
	var generation: int = _session_generation
	var used_access: String = _access_token
	var response: Dictionary = _checked(await _send(path,HTTPClient.METHOD_GET,{},true),path,HTTPClient.METHOD_GET)
	if str(player.get("id","")) != identity or generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if int(response.status) != 401: return response
	if _refresh_token.is_empty():
		clear_session()
		return response
	while _busy: await get_tree().process_frame
	if str(player.get("id","")) != identity or generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	_busy = true
	response = await _renew_session(generation,path,HTTPClient.METHOD_GET,{},"",used_access)
	_busy = false
	if str(player.get("id","")) != identity or generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if response.status == 401 or (response.get("refresh_failed",false) and not refresh_retry_safe(response)): clear_session()
	return response

func logout() -> Dictionary:
	var token: String = _access_token
	clear_session()
	var storage_failed: bool = persistence_error
	# Revocation uses the captured credential on its own request; local sign-out
	# is immediate even while another operation is rotating the session.
	if token.is_empty(): return _failure("SESSION_STORAGE_ERROR") if storage_failed else {"ok":true,"status":200,"data":{},"error":""}
	var response: Dictionary = await _send("/auth/logout",HTTPClient.METHOD_POST,{},false,"",PackedStringArray(["Authorization: Bearer "+token]))
	return _failure("SESSION_STORAGE_ERROR") if storage_failed else response

func upload_track(name_value: String, document: Dictionary, key: String) -> Dictionary:
	return await request_api("/tracks",HTTPClient.METHOD_POST,{"name":name_value,"document":document},key,true)

func race_ticket(version_id: String, vehicle_id: String, key: String, purpose: String = "race") -> Dictionary:
	return await request_api("/run-tickets",HTTPClient.METHOD_POST,{"version_id":version_id,"vehicle_id":vehicle_id,"purpose":purpose},key,true)

static func _pack_replay(frames: Array, rewinds: Array, compact: bool = true) -> Dictionary:
	# Godot's JSON parser returns floats, including integers restored from the outbox.
	# Preserve the strict wire schema without accepting fractional/corrupt controls.
	var packed: Array = []
	for frame: Variant in frames:
		if not frame is Array or frame.size() not in [3, 4, 5]: return {}
		var values: Array[int] = []
		for value: Variant in frame:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != float(int(value)): return {}
			values.append(int(value))
		packed.append(values)
	var replay: Dictionary = {"schema":"bmt-replay-v1","frames":packed}
	if not rewinds.is_empty():
		replay.schema = "bmt-replay-v2"
		replay.rewinds = []
		for source: Dictionary in rewinds:
			var event: Dictionary = {"receipt_id":str(source.get("receipt_id",""))}
			for field: String in ["input_offset","from_tick","to_tick"]:
				var value: Variant = source.get(field)
				if not (value is int or value is float) or not is_finite(float(value)) or float(value) != float(int(value)): return {}
				event[field] = int(value)
			replay.rewinds.append(event)

	var controls := PackedByteArray()
	controls.resize(packed.size()*6)
	for index: int in range(packed.size()):
		var frame: Array = packed[index]
		if frame[0] < -127 or frame[0] > 127 or frame[1] < 0 or frame[1] > 255 or frame[2] < 0 or frame[2] > 255 or (frame.size() >= 4 and (frame[3] < 0 or frame[3] > 255)) or (frame.size() == 5 and (index != 0 or frame[4] not in [1,2])): return {}
		controls[index*6] = frame.size()
		controls[index*6+1] = int(frame[0])+127
		controls[index*6+2] = int(frame[1])
		controls[index*6+3] = int(frame[2])
		controls[index*6+4] = int(frame[3]) if frame.size() >= 4 else 0
		controls[index*6+5] = int(frame[4]) if frame.size() == 5 else 0
	if not compact: return replay
	var wire: Dictionary = {"schema":"bmt-packed-input-v1","replay_schema":replay.schema,"frame_count":packed.size(),"controls":Marshalls.raw_to_base64(controls)}
	if replay.has("rewinds"): wire.rewinds = replay.rewinds
	return wire

func submit_run(ticket_id: String, frames: Array, key: String, rewinds: Array = []) -> Dictionary:
	var generation: int = _session_generation
	var origin: String = _base_url
	var compact: bool = not _disable_packed and _capabilities.get("replay_wire_schema","") == "bmt-packed-input-v1"
	var replay: Variant = await _background(_pack_replay.bind(frames,rewinds,compact))
	if generation != _session_generation or origin != _base_url: return _failure("ACCOUNT_CHANGED")
	if not replay is Dictionary or replay.is_empty(): return _failure("INVALID_REPLAY",422)
	var response: Dictionary = await request_api("/runs",HTTPClient.METHOD_POST,{"ticket_id":ticket_id,"replay":replay},key,true)
	if compact and int(response.status) == 422 and (str(response.error).to_lower().contains("replay envelope") or str(response.error) in ["INVALID_PACKED_REPLAY","UNSUPPORTED_REPLAY_SCHEMA"]):
		_disable_packed = true
		replay = await _background(_pack_replay.bind(frames,rewinds,false))
		if generation != _session_generation or origin != _base_url: return _failure("ACCOUNT_CHANGED")
		if not replay is Dictionary or replay.is_empty(): return _failure("INVALID_REPLAY",422)
		response = await request_api("/runs",HTTPClient.METHOD_POST,{"ticket_id":ticket_id,"replay":replay},key,true)
	return response

static func _whole(value: Variant, minimum: int = 0, maximum: int = 9007199254740991) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and float(value) == float(int(value))

static func _text(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 256

static func valid_run(data: Variant) -> bool:
	return data is Dictionary and _text(data.get("run_id")) and data.get("status") in ["queued","verifying","verified","rejected","failed"] and (data.status not in ["failed","rejected"] or _text(data.get("failure_code"))) and (not data.get("outcome") is Dictionary or _whole(data.get("slot"),0,4))

static func valid_wallet(data: Variant) -> bool:
	return data is Dictionary and _whole(data.get("balance")) and _whole(data.get("free"),0,1) and _whole(data.get("reset_at"),1)

static func valid_response(path: String, method: HTTPClient.Method, data: Variant) -> bool:
	if not data is Dictionary: return false
	var endpoint: String = path.get_slice("?",0)
	if endpoint == "/auth/google/browser/prepare": return _text(data.get("client_id")) and _text(data.get("nonce"))
	if endpoint == "/auth/google/browser/complete": return data.get("status") == "complete"
	if endpoint == "/auth/google/browser/start": return _text(data.get("poll_token")) and data.get("browser_url") is String and data.browser_url.length() < 4096
	if endpoint == "/auth/google/challenge": return _text(data.get("challenge_id")) and _text(data.get("nonce"))
	if endpoint.begins_with("/auth/") and endpoint not in ["/auth/logout","/auth/logout-all","/auth/google/challenge","/auth/google/browser/start"]:
		if data.get("status") == "pending": return true
		return _text(data.get("access_token")) and _text(data.get("refresh_token")) and data.get("player") is Dictionary and _text(data.player.get("id"))
	if endpoint == "/me": return _text(data.get("id"))
	if endpoint == "/runs/status":
		if not data.get("items") is Array or data.items.size() > 32: return false
		for item: Variant in data.items:
			if not valid_run(item): return false
		return true
	if endpoint == "/runs" or (endpoint.begins_with("/runs/") and not endpoint.ends_with("/replay")): return valid_run(data)
	if endpoint == "/resumes": return valid_wallet(data)
	if endpoint == "/resume-races": return _text(data.get("race_id")) and _whole(data.get("used"),0,3)
	if endpoint.begins_with("/resume-races/") and endpoint.ends_with("/resumes"): return _text(data.get("receipt_id")) and _whole(data.get("used"),1,3) and valid_wallet(data.get("wallet"))
	if endpoint == "/resume-recovery": return data.get("state") in ["absent","consumed","abandoned"] and valid_wallet(data.get("wallet")) and (data.state != "consumed" or (_text(data.get("receipt_id")) and _whole(data.get("used"),1,3)))
	if (endpoint == "/run-tickets" or (endpoint.begins_with("/rivalry/") and endpoint.ends_with("/tickets"))) and method == HTTPClient.METHOD_POST:
		if not _text(data.get("ticket_id")) or not data.get("manifest") is Dictionary: return false
		for key: String in ["track_content_hash","engine_version","track_schema","replay_schema","verifier_version","physics_version","compiler_version","rules_key","config_hash"]:
			if not _text(data.manifest.get(key)): return false
		return _whole(data.manifest.get("tick_rate"),1) and _whole(data.manifest.get("laps"),1)
	if endpoint == "/tracks" and method == HTTPClient.METHOD_GET:
		if not data.get("items") is Array: return false
		for item: Variant in data.items:
			if not item is Dictionary: return false
	if (endpoint == "/tracks" and method == HTTPClient.METHOD_POST) or (endpoint.begins_with("/tracks/") and endpoint.ends_with("/versions")) or (endpoint.begins_with("/track-versions/") and endpoint.ends_with("/publish")):
		return _text(data.get("track_id")) and _text(data.get("version_id"))
	if endpoint == "/me/tracks":
		if not data.get("items") is Array: return false
		for item: Variant in data.items:
			if not item is Dictionary or not _text(item.get("version_id")) or not _text(item.get("content_hash")): return false
	if endpoint.begins_with("/rivalry/tickets/") and endpoint.ends_with("/result"):
		return data.get("status") in ["upload_pending","queued","verifying","verified","rejected","failed","expired"] and (not data.get("outcome") is Dictionary or _whole(data.get("slot"),0,4))
	return true

func _checked(response: Dictionary, path: String, method: HTTPClient.Method) -> Dictionary:
	return _failure("INVALID_RESPONSE",502) if response.get("ok",false) and not valid_response(path,method,response.get("data")) else response

func rate_track(version_id: String, score: int, key: String) -> Dictionary:
	return await request_api("/track-versions/"+version_id.uri_encode()+"/rating",HTTPClient.METHOD_PUT,{"score":score},key,true)
