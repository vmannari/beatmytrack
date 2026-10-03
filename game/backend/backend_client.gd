extends Node
signal identity_changed
## Optional online adapter. The local game and canonical step never depend on it.
## Browser sign-in and UI live in account_controller.gd. Only the rotating refresh token is persisted in the private application directory.
const MAX_RESPONSE_BYTES: int = 8388608
var _base_url: String = ""
var _access_token: String = ""
var _refresh_token: String = ""
var _busy: bool = false
var _session_generation: int = 0
var player: Dictionary = {}
# Empty disables persistence for standalone adapters/tests. Never include in exports.
var session_path: String = ""
var persistence_error: bool = false
var _public_reads: Array[HTTPRequest] = []

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
	return bool(response.get("not_delivered",false)) or (int(response.get("status",0)) == 429 and str(response.get("error","")) == "RATE_LIMITED") or (int(response.get("status",0)) == 503 and str(response.get("error","")) == "REQUEST_VALIDATION_BUSY")

func configure(base_url: String) -> Error:
	if _busy: return ERR_BUSY
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

func clear_session() -> void:
	_session_generation += 1
	persistence_error = false
	if not session_path.is_empty() and (not _access_token.is_empty() or FileAccess.file_exists(session_path)):
		# A durable sign-out fence also protects restarts if an open file cannot
		# be removed on this platform. Only a later successful sign-in removes it.
		var fence := FileAccess.open(session_path+".signed_out",FileAccess.WRITE)
		if fence == null: persistence_error = true
		else:
			fence.store_string("signed_out")
			fence.flush()
			persistence_error = fence.get_error() != OK
			fence.close()
	_forget_saved_session()
	_access_token = ""
	_refresh_token = ""
	player = {}
	identity_changed.emit()

func _forget_saved_session() -> void:
	if session_path.is_empty(): return
	for suffix: String in ["", ".tmp"]:
		if FileAccess.file_exists(session_path + suffix):
			if DirAccess.remove_absolute(session_path + suffix) != OK: persistence_error = true

func _save_session() -> void:
	if session_path.is_empty(): return
	var config := ConfigFile.new()
	config.set_value("session", "url", _base_url)
	config.set_value("session", "refresh_token", _refresh_token)
	var temporary: String = session_path + ".tmp"
	persistence_error = config.save(temporary) != OK
	if not persistence_error:
		persistence_error = DirAccess.rename_absolute(temporary, session_path) != OK
	if not persistence_error and FileAccess.file_exists(session_path+".signed_out"):
		persistence_error = DirAccess.remove_absolute(session_path+".signed_out") != OK
	if persistence_error: _forget_saved_session()

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
	var response: Dictionary = _remember(await _send("/auth/refresh", HTTPClient.METHOD_POST, {"refresh_token":token}, false),generation)
	if not response.ok and not refresh_retry_safe(response): clear_session()
	_busy = false
	return response

func signed_in() -> bool:
	return not _access_token.is_empty()

static func new_idempotency_key() -> String:
	return Crypto.new().generate_random_bytes(24).hex_encode()

func _failure(code: String, status: int = 0) -> Dictionary:
	return {"ok":false,"status":status,"error":code,"data":{}}

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
	var request := HTTPRequest.new()
	request.timeout = 110.0 if path == "/tracks" or path.ends_with("/versions") else 30.0
	request.body_size_limit = MAX_RESPONSE_BYTES
	request.max_redirects = 0 # Never forward credentials to a redirect target.
	add_child(request)
	var body: String = "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	if body.to_utf8_buffer().size() > MAX_RESPONSE_BYTES:
		request.queue_free()
		return _failure("REQUEST_TOO_LARGE")
	var start: Error = request.request(_base_url+"/v1"+path,headers,method,body)
	var origin: String = _base_url
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
	var bytes: PackedByteArray = completed[3]
	var parsed: Variant = {} if bytes.is_empty() else JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary: return _failure("INVALID_RESPONSE",status)
	var retry_after: int = 0
	for header: String in completed[2]:
		if header.to_lower().begins_with("retry-after:"): retry_after = clampi(int(header.get_slice(":",1).strip_edges()),1,60)
	return {"ok":status >= 200 and status < 300,"status":status,"data":parsed,"body":bytes.get_string_from_utf8(),"retry_after":retry_after,"error":"" if status >= 200 and status < 300 else str(parsed.get("detail","HTTP_ERROR"))}

func _remember(response: Dictionary, generation: int = -1) -> Dictionary:
	if generation != -1 and generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if not response.ok: return response
	var data: Dictionary = response.data
	if not data.get("access_token") is String or not data.get("refresh_token") is String or not data.get("player") is Dictionary:
		clear_session()
		return _failure("INVALID_SESSION_RESPONSE")
	_access_token = data.access_token
	_refresh_token = data.refresh_token
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
		return await _send(path,method,payload,false,idempotency_key)
	if authenticated and method == HTTPClient.METHOD_GET:
		return await _authenticated_read(path)
	var identity: String = str(player.get("id",""))
	var generation: int = _session_generation
	while _busy: await get_tree().process_frame
	if authenticated and (str(player.get("id","")) != identity or generation != _session_generation): return _failure("ACCOUNT_CHANGED")
	_busy = true
	var response: Dictionary = await _send(path,method,payload,authenticated,idempotency_key)
	if authenticated and (str(player.get("id","")) != identity or generation != _session_generation):
		_busy = false
		return _failure("ACCOUNT_CHANGED")
	if authenticated and response.status == 401 and not _refresh_token.is_empty():
		var refresh: Dictionary = _remember(await _send("/auth/refresh",HTTPClient.METHOD_POST,{"refresh_token":_refresh_token},false),generation)
		if generation != _session_generation:
			_busy = false
			return _failure("ACCOUNT_CHANGED")
		if refresh.ok:
			response = await _send(path,method,payload,true,idempotency_key)
			if generation != _session_generation:
				_busy = false
				return _failure("ACCOUNT_CHANGED")
			if response.status == 401: clear_session()
		else:
			# Refresh rotation is single use; ambiguous failures require sign-in.
			if not refresh_retry_safe(refresh): clear_session()
			response = refresh
	elif authenticated and response.status == 401:
		clear_session()
	_busy = false
	return response

func _authenticated_read(path: String) -> Dictionary:
	var identity: String = str(player.get("id",""))
	var generation: int = _session_generation
	var refresh_token: String = _refresh_token
	var response: Dictionary = await _send(path,HTTPClient.METHOD_GET,{},true)
	if str(player.get("id","")) != identity or generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if int(response.status) != 401: return response
	if refresh_token.is_empty():
		clear_session()
		return response
	while _busy: await get_tree().process_frame
	if str(player.get("id","")) != identity or generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	# Only the first failed reader rotates; others reuse the newly issued session.
	if _refresh_token == refresh_token:
		_busy = true
		var refresh: Dictionary = _remember(await _send("/auth/refresh",HTTPClient.METHOD_POST,{"refresh_token":refresh_token},false),generation)
		_busy = false
		if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
		if not refresh.ok:
			if not refresh_retry_safe(refresh): clear_session()
			return refresh
	response = await _send(path,HTTPClient.METHOD_GET,{},true)
	if str(player.get("id","")) != identity or generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if response.status == 401: clear_session()
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

func submit_run(ticket_id: String, frames: Array, key: String, rewinds: Array = []) -> Dictionary:
	# Godot's JSON parser returns floats, including integers restored from the outbox.
	# Preserve the strict wire schema without accepting fractional/corrupt controls.
	var packed: Array = []
	for frame: Variant in frames:
		if not frame is Array or frame.size() not in [3, 4, 5]: return _failure("INVALID_REPLAY")
		var values: Array[int] = []
		for value: Variant in frame:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != float(int(value)): return _failure("INVALID_REPLAY")
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
				if not (value is int or value is float) or not is_finite(float(value)) or float(value) != float(int(value)): return _failure("INVALID_REPLAY")
				event[field] = int(value)
			replay.rewinds.append(event)
	return await request_api("/runs",HTTPClient.METHOD_POST,{"ticket_id":ticket_id,"replay":replay},key,true)

func rate_track(version_id: String, score: int, key: String) -> Dictionary:
	return await request_api("/track-versions/"+version_id.uri_encode()+"/rating",HTTPClient.METHOD_PUT,{"score":score},key,true)
