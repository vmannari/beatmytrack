extends Node
signal identity_changed
## Optional online adapter. The local game and canonical step never depend on it.
## Browser sign-in and UI live in account_controller.gd. Persisted credentials are protected by the platform vault.
const MAX_RESPONSE_BYTES: int = 8388608
const INLINE_RESPONSE_BYTES: int = 32768
var _base_url: String = ""
var _access_token: String = ""
var _refresh_token: String = ""
var _login_id: String = ""
var _busy: bool = false
var _refresh_busy: bool = false
var _session_generation: int = 0
var player: Dictionary = {}
# Empty disables persistence for standalone adapters/tests. Never include in exports.
var session_path: String = ""
var persistence_error: bool = false
var _public_reads: Array[HTTPRequest] = []
var _telemetry_requests: Array[HTTPRequest] = []
var _telemetry_epoch: int = 1
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
var session_vault: RefCounted = preload("res://backend/session_vault.gd").new()
var _idle_requests: Array[HTTPRequest] = []
var network_health: RefCounted = preload("res://backend/network_health.gd").new()
var _pending_network_context: Dictionary = {}

func _vault_context() -> String:
	return "bmt-session-v1/"+_base_url+"/"+ProjectSettings.globalize_path(session_path)

func _write_saved_config(config: ConfigFile) -> Error:
	var sealed: String = session_vault.seal(config.encode_to_text(),_vault_context())
	if sealed.is_empty(): return ERR_UNAVAILABLE
	var temporary: String = session_path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(sealed)
	file.flush()
	var result: Error = file.get_error()
	file.close()
	return DirAccess.rename_absolute(temporary,session_path) if result == OK else result

func _load_saved_config(config: ConfigFile, migrate: bool = false) -> Error:
	var file := FileAccess.open(session_path,FileAccess.READ)
	if file == null: return FileAccess.get_open_error()
	if file.get_length() > 90000: return ERR_FILE_CORRUPT
	var text: String = file.get_as_text()
	file.close()
	var protected: bool = text.begins_with(preload("res://backend/session_vault.gd").HEADER)
	if protected: text = session_vault.open(text,_vault_context())
	elif not session_vault.available(): return ERR_UNAVAILABLE
	if text.is_empty(): return ERR_FILE_CORRUPT
	var result: Error = config.parse(text)
	# Migration occurs under the same inter-process rotation lease, before
	# sending any refresh request. A failed vault write cannot consume a token.
	if result == OK and not protected and migrate:
		if str(config.get_value("session","url","")) != _base_url: return ERR_INVALID_DATA
		result = _write_saved_config(config)
	return result

func _take_request() -> HTTPRequest:
	var request: HTTPRequest
	if _idle_requests.is_empty():
		request = HTTPRequest.new()
		add_child(request)
	else: request = _idle_requests.pop_back()
	request.set_meta("cancelled",false)
	request.set_meta("owner_id",0)
	return request

func _release_request(request: HTTPRequest) -> void:
	if not is_instance_valid(request): return
	# Reuse bounded nodes after their completion callback has unwound. HTTPRequest
	# owns its own connection lifecycle; this saves nodes, not TLS handshakes.
	if _idle_requests.size() < 4: _idle_requests.append(request)
	else: request.queue_free()

func _profile_request(path: String, phase: String, start: int) -> void:
	if not OS.is_debug_build() or (OS.get_environment("BMT_RACE_LOAD_PROFILE") != "1" and not "--profile-race-load" in OS.get_cmdline_user_args()): return
	# Category only: never log account/track/ticket IDs, URLs, headers or bodies.
	var kind: String = "challenge_source" if path.get_slice("?",0) == "/challenges/sources" else "race_ticket" if _race_ticket_path(path) else "track_document" if path.ends_with("/document") else "score_upload" if path == "/runs" else "other"
	print("RACE_LOAD_REQUEST ",JSON.stringify({"kind":kind,"phase":phase,"ms":(Time.get_ticks_usec()-start)/1000.0}))

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

func request_discovery(payload: Dictionary, owner_id: int, random_choice: bool = false) -> Dictionary:
	var path: String = "/discovery/random" if random_choice else "/discovery/tracks"
	if payload.get("section","all") == "saved": return await request_api(path,HTTPClient.METHOD_POST,payload,"",true)
	return _checked(await _send(path,HTTPClient.METHOD_POST,payload,false,"",PackedStringArray(),owner_id),path,HTTPClient.METHOD_POST)

func base_url() -> String:
	return _base_url

func auth_busy() -> bool:
	return _busy

func telemetry_supported() -> bool:
	var capability: Variant = _capabilities.get("product_telemetry",{})
	return signed_in() and capability is Dictionary and bool(capability.get("enabled",false)) and int(capability.get("schema_version",0)) == 1

func cancel_telemetry() -> void:
	_telemetry_epoch += 1
	for request: HTTPRequest in _telemetry_requests.duplicate():
		if not is_instance_valid(request): continue
		request.cancel_request()
		request.set_meta("cancelled",true)
		request.request_completed.emit(HTTPRequest.RESULT_REQUEST_FAILED,0,PackedStringArray(),PackedByteArray())

func quality_supported() -> bool:
	return quality_schema_version() > 0

func network_supported() -> bool:
	return telemetry_supported() and int(_capabilities.get("product_telemetry",{}).get("network_schema_version",0)) == 1

func _network_scope() -> String:
	return (_base_url+"/"+str(player.get("id",""))).sha256_text()

func note_upload_age(key: String, queued_server_at: int) -> void:
	if not network_supported(): return
	var current: int = server_now()
	var age: int = current-queued_server_at if queued_server_at > 0 and current >= queued_server_at else -1
	network_health.note_preparation(_network_scope(),key,0,age)

func note_request_preparation(key: String, usec: int) -> void:
	if network_supported(): network_health.note_preparation(_network_scope(),key,usec)

func quality_schema_version() -> int:
	if not telemetry_supported(): return 0
	var capability: Dictionary = _capabilities.get("product_telemetry",{})
	if capability.get("quality_schema_versions") is Array:
		for version: int in [3,2]:
			for supported: Variant in capability.quality_schema_versions:
				if _whole(supported,2,3) and int(supported) == version: return version
		return 0
	var version: int = int(capability.get("quality_schema_version",0))
	return version if telemetry_supported() and version in [2,3] else 0

func request_telemetry(payload: Dictionary) -> Dictionary:
	# Optional observations never reserve the mutation queue or rotate credentials.
	# Expired credentials retain the same durable events for a later normal sign-in.
	if not telemetry_supported() or _busy or _refresh_busy: return _failure("TELEMETRY_DEFERRED")
	return await _send("/telemetry/batches",HTTPClient.METHOD_POST,payload,true,"",PackedStringArray(),_telemetry_epoch)

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
	cancel_telemetry()
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
	# The same private file already holds the more powerful refresh credential.
	# Sharing its current access credential avoids rotation ping-pong between
	# game instances belonging to the same explicit login.
	config.set_value("session", "access_token", _access_token)
	config.set_value("session", "login_id", _login_id)
	config.set_value("session", "player_id", str(player.get("id","")))
	if not _refresh_request_id.is_empty(): config.set_value("session","refresh_request_id",_refresh_request_id)
	persistence_error = _write_saved_config(config) != OK
	if not session_vault.available(): _forget_saved_session()
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
	if not has_saved_session() or _load_saved_config(config) != OK:
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

func _renew_session(generation: int, path: String = "", method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, key: String = "", used_access: String = "", network_context: Dictionary = {}) -> Dictionary:
	# Serialize credentials independently from durable application mutations.
	# This also covers standalone clients without a persisted rotation lock.
	var began: int = Time.get_ticks_msec()
	while _refresh_busy:
		if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
		# Renewal may already be complete while its owner's original read is
		# still being retried under the rotation lock. Race authorization and
		# challenge-time lookup can use that credential without waiting for an
		# unrelated response or releasing either lock. Keep the exact request.
		if _independent_auth_request(path,method) and not _access_token.is_empty() and _access_token != used_access:
			var ticket: Dictionary = _checked(await _send(path,method,payload,true,key),path,method)
			return ticket if generation == _session_generation else _failure("ACCOUNT_CHANGED")
		if Time.get_ticks_msec()-began >= 35000:
			var waiting: Dictionary = _failure("SESSION_ROTATION_BUSY")
			waiting.not_delivered = true
			return waiting
		await get_tree().process_frame
	if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	_refresh_busy = true
	var lock := preload("res://backend/session_rotation_lock.gd").new(session_path)
	_rotation_locks.append(lock)
	var acquired: Error = await lock.acquire(get_tree())
	if acquired != OK:
		_rotation_locks.erase(lock)
		_refresh_busy = false
		var failed: Dictionary = _failure("SESSION_ROTATION_BUSY")
		failed.not_delivered = true
		return failed
	if not network_context.is_empty(): network_context.queue_us = int(network_context.get("queue_us",0))+maxi(0,Time.get_ticks_msec()-began)*1000
	var response: Dictionary = await _renew_locked(generation,path,method,payload,key,used_access,network_context)
	lock.release()
	_rotation_locks.erase(lock)
	_refresh_busy = false
	return response

func _renew_locked(generation: int, path: String, method: HTTPClient.Method, payload: Dictionary, key: String, used_access: String, network_context: Dictionary = {}) -> Dictionary:
	if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if not path.is_empty() and _access_token != used_access:
		# An earlier request in this client already renewed while we waited.
		var retried: Dictionary = _checked(await _send_context(path,method,payload,true,key,network_context),path,method)
		if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
		if int(retried.status) != 401: return retried
	var expected_player: String = str(player.get("id",""))
	var config := ConfigFile.new()
	if not session_path.is_empty() and session_vault.available():
		if not has_saved_session() or _load_saved_config(config,true) != OK:
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
		var saved_access: String = str(config.get_value("session","access_token",""))
		if not path.is_empty() and not saved_access.is_empty() and saved_access != _access_token and _refresh_request_id.is_empty():
			_access_token = saved_access
			var reused: Dictionary = _checked(await _send_context(path,method,payload,true,key,network_context),path,method)
			if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
			# A concurrent explicit login/sign-out still fences this request, even
			# when the already issued access credential was accepted by the server.
			var latest := ConfigFile.new()
			if not has_saved_session() or _load_saved_config(latest) != OK or _stored_login_id(latest) != _login_id:
				clear_session(true)
				return _failure("ACCOUNT_CHANGED")
			if int(reused.status) != 401: return reused
	var supports_recovery: bool = not _refresh_request_id.is_empty() or int(_capabilities.get("refresh_recovery_seconds",0)) > 0
	var body: Dictionary = {"refresh_token":_refresh_token}
	if supports_recovery:
		if _refresh_request_id.is_empty(): _refresh_request_id = Crypto.new().generate_random_bytes(24).hex_encode()
		body.refresh_request_id = _refresh_request_id
		if not session_path.is_empty() and session_vault.available():
			config.set_value("session","refresh_request_id",_refresh_request_id)
			if _write_saved_config(config) != OK:
				var failure: Dictionary = _failure("SESSION_STORAGE_ERROR")
				failure.not_delivered = true
				return failure
	var refresh: Dictionary = _checked(await _send("/auth/refresh",HTTPClient.METHOD_POST,body,false),"/auth/refresh",HTTPClient.METHOD_POST)
	if supports_recovery and not refresh.ok: refresh.recoverable_refresh = true
	if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if not session_path.is_empty() and session_vault.available():
		var current := ConfigFile.new()
		if not has_saved_session() or _load_saved_config(current) != OK or _stored_login_id(current) != _login_id:
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
	var response: Dictionary = _checked(await _send_context(path,method,payload,true,key,network_context),path,method)
	if generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	return response

func signed_in() -> bool:
	return not _access_token.is_empty()

static func new_idempotency_key(unix_time: int = 0) -> String:
	var random: String = Crypto.new().generate_random_bytes(24).hex_encode()
	return "v2."+str(unix_time)+"."+random if unix_time > 0 else "op."+random

func server_now() -> int:
	return _server_sample+maxi(0,Time.get_ticks_msec()-_server_sample_msec)/1000 if _server_sample > 0 else 0

func test_drivers_available() -> bool:
	return OS.is_debug_build() and signed_in() and bool(_capabilities.get("test_drivers",false))

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
	var parser := JSON.new()
	var parsed: Variant = parser.data if parser.parse(body) == OK else null
	return {"parsed":parsed,"body":body,"cache_data":parsed.duplicate(true) if cacheable and parsed is Dictionary else {}}

func remember_run(value: Dictionary) -> void:
	if not value.has_all(["ticket_id","status"]): return
	_race_status_cache[str(value.ticket_id)] = {"data":value,"at":Time.get_ticks_msec()}
	while _race_status_cache.size() > 32: _race_status_cache.erase(_race_status_cache.keys()[0])

func recent_run(ticket_id: String) -> Dictionary:
	var cached: Dictionary = _race_status_cache.get(ticket_id,{})
	var duration: int = 250 if cached.get("data",{}).get("status","") in ["queued","verifying"] else 3000
	return cached.get("data",{}) if Time.get_ticks_msec()-int(cached.get("at",-10000)) < duration else {}

func _background(work: Callable) -> Variant:
	var thread := Thread.new()
	if thread.start(work) != OK: return null
	_encoding_threads.append(thread)
	while thread.is_alive(): await get_tree().process_frame
	_encoding_threads.erase(thread)
	return thread.wait_to_finish()

func _network_context_key(path: String, method: int, key: String) -> String:
	return JSON.stringify([_session_generation,path,method,key]).sha256_text()

func _send_context(path: String, method: HTTPClient.Method, payload: Dictionary, authorized: bool, key: String, context: Dictionary) -> Dictionary:
	# _send consumes this small context before its first await. Preserve the
	# established transport signature and isolated test/platform overrides.
	var identity: String = _network_context_key(path,method,key)
	_pending_network_context[identity] = context
	while _pending_network_context.size() > 256: _pending_network_context.erase(_pending_network_context.keys()[0])
	var response: Dictionary = await _send(path,method,payload,authorized,key)
	if _pending_network_context.has(identity) and is_same(_pending_network_context[identity],context): _pending_network_context.erase(identity)
	return response

func _send(path: String, method: HTTPClient.Method, payload: Dictionary, authorized: bool, idempotency_key: String = "", extra_headers: PackedStringArray = [], owner_id: int = 0) -> Dictionary:
	var identity: String = _network_context_key(path,method,idempotency_key)
	var network_context: Dictionary = _pending_network_context.get(identity,{})
	_pending_network_context.erase(identity)
	var monitor = preload("res://backend/network_health.gd")
	var category: String = monitor.category(path)
	var collect: bool = network_supported() and not str(player.get("id","")).is_empty() and not category.is_empty()
	var scope: String = _network_scope()
	var generation: int = _session_generation
	var context: Dictionary = network_context if not network_context.is_empty() else {"attempt":0,"queue_us":0}
	var attempt: int = int(context.get("attempt",0)); context.attempt = attempt+1
	var metrics: Dictionary = {"collect":collect,"request_id":"","http_status":0}
	if collect:
		metrics.merge(network_health.begin(scope,idempotency_key,attempt))
		metrics.queue_ms = clampi(int(context.get("queue_us",0))/1000,0,monitor.MAX_MS)
	context.queue_us = 0
	var started: int = Time.get_ticks_usec()
	var response: Dictionary = await _send_transport(path,method,payload,authorized,idempotency_key,extra_headers,owner_id,metrics)
	if not str(metrics.request_id).is_empty(): response.request_id = metrics.request_id
	if collect and generation == _session_generation and scope == _network_scope():
		metrics.encode_ms = clampi((int(metrics.get("encode_us",0))+int(metrics.extra_encode_us))/1000,0,monitor.MAX_MS)
		metrics.total_ms = clampi((Time.get_ticks_usec()-started+int(metrics.extra_encode_us))/1000+int(metrics.queue_ms),0,monitor.MAX_MS)
		network_health.record(scope,category,monitor.method_name(method),response,metrics)
	return response

func _send_transport(path: String, method: HTTPClient.Method, payload: Dictionary, authorized: bool, idempotency_key: String, extra_headers: PackedStringArray, owner_id: int, metrics: Dictionary) -> Dictionary:
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
	var profile_start: int = Time.get_ticks_usec()
	var packet: Variant = {"body":PackedByteArray(),"compressed":false} if method == HTTPClient.METHOD_GET else await _background(_encode_request.bind(payload,not _disable_gzip and "gzip" in _capabilities.get("upload_encodings",[])))
	_profile_request(path,"encode",profile_start)
	if metrics.collect: metrics.encode_us = Time.get_ticks_usec()-profile_start
	if not packet is Dictionary: return _failure("REQUEST_ENCODING_FAILED")
	if packet.get("too_large",false): return _failure("REQUEST_TOO_LARGE",413)
	if origin != _base_url or (authorized and generation != _session_generation): return _failure("ACCOUNT_CHANGED")
	# A menu request may finish encoding after the player starts loading a race.
	# Its owner cancellation fence prevents starting network work after that point.
	if path == "/telemetry/batches" and owner_id != 0 and owner_id != _telemetry_epoch: return _failure("CANCELLED")
	if packet.compressed: headers.append("Content-Encoding: gzip")
	if metrics.collect: metrics.request_body_bytes = packet.body.size()
	var request: HTTPRequest = _take_request()
	request.use_threads = true
	request.timeout = 10.0 if path == "/telemetry/batches" else 2.0 if "/ghosts/" in path else 30.0
	request.body_size_limit = 16384 if path == "/telemetry/batches" else MAX_RESPONSE_BYTES
	request.max_redirects = 0 # Never forward credentials to a redirect target.
	profile_start = Time.get_ticks_usec()
	var start: Error = request.request_raw(_base_url+"/v1"+path,headers,method,packet.body)
	if start != OK:
		_release_request.call_deferred(request)
		var failed: Dictionary = _failure("REQUEST_START_FAILED")
		failed.not_delivered = true
		return failed
	if owner_id != 0 and (method == HTTPClient.METHOD_GET or path.begins_with("/discovery/")):
		request.set_meta("owner_id",owner_id)
		_public_reads.append(request)
	if path == "/telemetry/batches": _telemetry_requests.append(request)
	var completed: Array = await request.request_completed
	_profile_request(path,"http",profile_start)
	if metrics.collect:
		metrics.http_ms = clampi((Time.get_ticks_usec()-profile_start)/1000,0,preload("res://backend/network_health.gd").MAX_MS)
		metrics.response_body_bytes = (completed[3] as PackedByteArray).size()
	metrics.request_id = preload("res://backend/network_health.gd").request_id(completed[2])
	metrics.http_status = int(completed[1])
	_public_reads.erase(request)
	_telemetry_requests.erase(request)
	var cancelled: bool = bool(request.get_meta("cancelled",false))
	_release_request.call_deferred(request)
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
	profile_start = Time.get_ticks_usec()
	var decoded: Variant
	if bytes.is_empty(): decoded = {"parsed":{},"body":"","cache_data":{}}
	elif bytes.size() <= INLINE_RESPONSE_BYTES: decoded = _decode_response(bytes,cacheable)
	else: decoded = await _background(_decode_response.bind(bytes,cacheable))
	_profile_request(path,"decode",profile_start)
	if metrics.collect: metrics.decode_ms = clampi((Time.get_ticks_usec()-profile_start)/1000,0,preload("res://backend/network_health.gd").MAX_MS)
	if not decoded is Dictionary: return _failure("INVALID_RESPONSE",status)
	var parsed: Variant = decoded.parsed
	if str(metrics.request_id).is_empty() and parsed is Dictionary and parsed.get("request_id") is String:
		metrics.request_id = preload("res://backend/network_health.gd").request_id(PackedStringArray(["X-Request-Id: "+str(parsed.request_id)]))
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
	var retry_after: int = _retry_after(completed[2],server_now() if _server_sample > 0 else -1)
	return {"ok":status >= 200 and status < 300,"status":status,"data":parsed,"body":decoded.body,"retry_after":retry_after,"error":"" if status >= 200 and status < 300 else str(parsed.get("detail","HTTP_ERROR"))}

static func _retry_after(headers: PackedStringArray, reference_unix: int = -1) -> int:
	var reference: int = reference_unix if reference_unix >= 0 else int(Time.get_unix_time_from_system())
	if reference_unix < 0:
		for header: String in headers:
			if header.to_lower().begins_with("date:"):
				var server_date: int = _http_date(header.substr(5).strip_edges(),reference)
				if server_date >= 0: reference = server_date
	for header: String in headers:
		if header.to_lower().begins_with("retry-after:"):
			var value: String = header.substr(header.find(":")+1).strip_edges()
			if value.length() <= 10 and value.is_valid_int() and not value.begins_with("-") and not value.begins_with("+"): return clampi(int(value),0,3600)
			var date: int = _http_date(value,reference)
			if date >= 0: return clampi(date-reference,0,3600)
	return 0

static func _http_date(value: String, reference: int) -> int:
	# HTTP recipients accept IMF-fixdate and both obsolete HTTP-date forms.
	if value.length() > 80: return -1
	var patterns: Array[String] = [
		"^(Mon|Tue|Wed|Thu|Fri|Sat|Sun), ([0-9]{2}) ([A-Z][a-z]{2}) ([0-9]{4}) ([0-9]{2}):([0-9]{2}):([0-9]{2}) GMT$",
		"^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday), ([0-9]{2})-([A-Z][a-z]{2})-([0-9]{2}) ([0-9]{2}):([0-9]{2}):([0-9]{2}) GMT$",
		"^(Mon|Tue|Wed|Thu|Fri|Sat|Sun) ([A-Z][a-z]{2}) +([0-9]{1,2}) ([0-9]{2}):([0-9]{2}):([0-9]{2}) ([0-9]{4})$"]
	var months: Array[String] = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
	for index: int in range(patterns.size()):
		var match_value: RegExMatch = RegEx.create_from_string(patterns[index]).search(value)
		if match_value == null: continue
		var year: int = int(match_value.get_string(7 if index == 2 else 4))
		if index == 1:
			var current_year: int = Time.get_datetime_dict_from_unix_time(reference).year
			year += ((current_year+50)/100)*100
			if year > current_year+50: year -= 100
		var month: int = months.find(match_value.get_string(2 if index == 2 else 3))+1
		var date: Dictionary = {"year":year,"month":month,"day":int(match_value.get_string(3 if index == 2 else 2)),"hour":int(match_value.get_string(4 if index == 2 else 5)),"minute":int(match_value.get_string(5 if index == 2 else 6)),"second":int(match_value.get_string(6 if index == 2 else 7))}
		if index == 1:
			var reference_date: Dictionary = Time.get_datetime_dict_from_unix_time(reference)
			if int(date.year) == int(reference_date.year)+50:
				for field: String in ["month","day","hour","minute","second"]:
					if int(date[field]) > int(reference_date[field]): date.year -= 100; break
					if int(date[field]) < int(reference_date[field]): break
				year = int(date.year)
		if year < 1970 or year > 9999 or month == 0 or date.day < 1 or date.day > 31 or date.hour > 23 or date.minute > 59 or date.second > 59: return -1
		var days: Array[int] = [31,29 if year%4 == 0 and (year%100 != 0 or year%400 == 0) else 28,31,30,31,30,31,31,30,31,30,31]
		if date.day > days[month-1]: return -1
		var timestamp: int = Time.get_unix_time_from_datetime_dict(date)
		var round_trip: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
		for field: String in date:
			if date[field] != round_trip[field]: return -1
		return timestamp
	return -1

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
	var payload: Dictionary = {"id_token":id_token,"challenge_id":challenge_id}
	if not display_name.is_empty(): payload.display_name = display_name
	var response: Dictionary = _remember(await _send("/auth/google",HTTPClient.METHOD_POST,payload,false),generation)
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
	# Fresh race authorization is independent of a prior durable score upload.
	# Healthy tickets bypass the mutation queue; credential rotation stays serialized.
	if authenticated and method == HTTPClient.METHOD_POST and _race_ticket_path(path):
		return await _authenticated_read(path,method,payload,idempotency_key)
	var identity: String = str(player.get("id",""))
	var generation: int = _session_generation
	var profile_wait: int = Time.get_ticks_usec()
	while _busy: await get_tree().process_frame
	_profile_request(path,"queue",profile_wait)
	if authenticated and (str(player.get("id","")) != identity or generation != _session_generation): return _failure("ACCOUNT_CHANGED")
	_busy = true
	var used_access: String = _access_token
	var network_context: Dictionary = {"attempt":0,"queue_us":Time.get_ticks_usec()-profile_wait}
	var response: Dictionary = _checked(await _send_context(path,method,payload,authenticated,idempotency_key,network_context),path,method)
	if response.status == 415 and not _disable_gzip:
		_disable_gzip = true
		response = _checked(await _send_context(path,method,payload,authenticated,idempotency_key,network_context),path,method)
	if authenticated and (str(player.get("id","")) != identity or generation != _session_generation):
		_busy = false
		return _failure("ACCOUNT_CHANGED")
	if authenticated and response.status == 401 and not _refresh_token.is_empty():
		response = await _renew_session(generation,path,method,payload,idempotency_key,used_access,network_context)
		if generation != _session_generation:
			_busy = false
			return _failure("ACCOUNT_CHANGED")
		if response.status == 401 or (response.get("refresh_failed",false) and not refresh_retry_safe(response)): clear_session()
	elif authenticated and response.status == 401:
		clear_session()
	_busy = false
	return response

static func _race_ticket_path(path: String) -> bool:
	return path == "/run-tickets" or ((path.begins_with("/rivalry/") or path.begins_with("/challenges/")) and path.get_slice_count("/") == 4 and path.ends_with("/tickets"))

static func _independent_auth_request(path: String, method: HTTPClient.Method) -> bool:
	# A tiny verified-time lookup must not queue behind durable uploads. Its
	# credential rotation uses the same independent lock as race authorization.
	return (method == HTTPClient.METHOD_POST and _race_ticket_path(path)) or (method == HTTPClient.METHOD_GET and path.get_slice("?",0) == "/challenges/sources")

func _authenticated_read(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, idempotency_key: String = "") -> Dictionary:
	var identity: String = str(player.get("id",""))
	var generation: int = _session_generation
	var used_access: String = _access_token
	var network_context: Dictionary = {"attempt":0,"queue_us":0}
	var response: Dictionary = _checked(await _send_context(path,method,payload,true,idempotency_key,network_context),path,method)
	if response.status == 415 and method != HTTPClient.METHOD_GET and not _disable_gzip:
		_disable_gzip = true
		response = _checked(await _send_context(path,method,payload,true,idempotency_key,network_context),path,method)
	if str(player.get("id","")) != identity or generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if int(response.status) != 401: return response
	if _refresh_token.is_empty():
		clear_session()
		return response
	var profile_wait: int = Time.get_ticks_usec()
	var independent: bool = _independent_auth_request(path,method)
	if not independent:
		while _busy: await get_tree().process_frame
	_profile_request(path,"refresh_queue",profile_wait)
	network_context.queue_us = Time.get_ticks_usec()-profile_wait
	if str(player.get("id","")) != identity or generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if not independent: _busy = true
	response = await _renew_session(generation,path,method,payload,idempotency_key,used_access,network_context)
	if not independent: _busy = false
	if str(player.get("id","")) != identity or generation != _session_generation: return _failure("ACCOUNT_CHANGED")
	if response.status == 401 or (response.get("refresh_failed",false) and not refresh_retry_safe(response)): clear_session()
	return response

func logout() -> Dictionary:
	var token: String = _access_token
	var refresh: String = _refresh_token
	clear_session()
	var storage_failed: bool = persistence_error
	# Revocation uses the captured credential on its own request; local sign-out
	# is immediate even while another operation is rotating the session.
	if token.is_empty() and refresh.is_empty(): return _failure("SESSION_STORAGE_ERROR") if storage_failed else {"ok":true,"status":200,"data":{},"error":""}
	var payload: Dictionary = {} if refresh.is_empty() else {"refresh_token":refresh}
	var headers := PackedStringArray() if token.is_empty() else PackedStringArray(["Authorization: Bearer "+token])
	var response: Dictionary = await _send("/auth/logout",HTTPClient.METHOD_POST,payload,false,"",headers)
	return _failure("SESSION_STORAGE_ERROR") if storage_failed else response

func upload_track(_name_value: String, _document: Dictionary, _key: String) -> Dictionary:
	return {"ok":false,"status":410,"error":"LOCAL_DRAFTS_ONLY","data":{}}

func race_ticket(version_id: String, vehicle_id: String, key: String, purpose: String = "race") -> Dictionary:
	return await request_api("/run-tickets",HTTPClient.METHOD_POST,{"version_id":version_id,"vehicle_id":vehicle_id,"purpose":purpose},key,true)

static func _pack_replay(frames: Array, rewinds: Array, compact: bool = true, race_proof: Dictionary = {}) -> Dictionary:
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
	if not race_proof.is_empty():
		if race_proof.get("schema","") != "bmt-race-proof-v1" or not race_proof.get("samples") is Array: return {}
		var samples: Array = []
		for row: Variant in race_proof.samples:
			if not row is Array or row.size() != 8: return {}
			for value: Variant in row:
				if not (value is int or value is float) or not is_finite(float(value)): return {}
			if float(row[0]) != float(int(row[0])) or float(row[6]) != float(int(row[6])): return {}
			var sample: Array = row.duplicate()
			sample[0] = int(row[0]); sample[6] = int(row[6])
			samples.append(sample)
		replay.race_proof = {"schema":"bmt-race-proof-v1","samples":samples}
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
	if replay.has("race_proof"): wire.race_proof = replay.race_proof
	return wire

static func _pack_trajectory(count: int, proof: Dictionary, rewinds: Array, ghost: Dictionary = {}) -> Dictionary:
	# Normalize the small movement record without encoding/scanning control frames.
	var normalized: Dictionary = _pack_replay([[0,0,0]],[],false,proof)
	if normalized.is_empty() or not normalized.has("race_proof"): return {}
	var events: Array = []
	for source: Dictionary in rewinds:
		events.append({"receipt_id":str(source.receipt_id),"input_offset":int(source.input_offset),"from_tick":int(source.from_tick),"to_tick":int(source.to_tick)})
	var path: Array = []
	for row: Array in normalized.race_proof.samples: path.append([row[0],row[1],row[2],row[6]])
	var result: Dictionary = {"schema":"bmt-trajectory-v1","input_count":count,"race_proof":{"schema":"bmt-race-path-v1","samples":path},"rewinds":events}
	if not ghost.is_empty(): result.ghost = ghost
	return result

func submit_run(ticket_id: String, frames: Array, key: String, rewinds: Array = [], race_proof: Dictionary = {}, ghost: Dictionary = {}) -> Dictionary:
	var generation: int = _session_generation
	var origin: String = _base_url
	var compact: bool = not _disable_packed and _capabilities.get("replay_wire_schema","") == "bmt-packed-input-v1"
	var trajectory: bool = bool(_capabilities.get("trajectory_verification",false)) and not race_proof.is_empty()
	var preparation: int = Time.get_ticks_usec()
	var replay: Variant = await _background(_pack_trajectory.bind(frames.size(),race_proof,rewinds,ghost) if trajectory else _pack_replay.bind(frames,rewinds,compact,race_proof))
	if generation != _session_generation or origin != _base_url: return _failure("ACCOUNT_CHANGED")
	note_request_preparation(key,Time.get_ticks_usec()-preparation)
	if not replay is Dictionary or replay.is_empty(): return _failure("INVALID_REPLAY",422)
	var response: Dictionary = await request_api("/runs",HTTPClient.METHOD_POST,{"ticket_id":ticket_id,"replay":replay},key,true)
	if not trajectory and compact and int(response.status) == 422 and (str(response.error).to_lower().contains("replay envelope") or str(response.error) in ["INVALID_PACKED_REPLAY","UNSUPPORTED_REPLAY_SCHEMA"]):
		_disable_packed = true
		replay = await _background(_pack_replay.bind(frames,rewinds,false,race_proof))
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
	if not data is Dictionary: return false
	for field: String in ["free_rewinds","ad_free"]:
		if data.has(field) and not data[field] is bool: return false
	return data is Dictionary and _whole(data.get("balance")) and _whole(data.get("free"),0,1) and _whole(data.get("reset_at"),1)

static func valid_response(path: String, method: HTTPClient.Method, data: Variant) -> bool:
	if not data is Dictionary: return false
	var endpoint: String = path.get_slice("?",0)
	if endpoint == "/auth/google/browser/cancel": return method == HTTPClient.METHOD_POST and data.is_empty()
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
	if (endpoint == "/run-tickets" or ((endpoint.begins_with("/rivalry/") or endpoint.begins_with("/challenges/")) and endpoint.ends_with("/tickets"))) and method == HTTPClient.METHOD_POST:
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
	if not response.get("ok",false) or valid_response(path,method,response.get("data")): return response
	var failed: Dictionary = _failure("INVALID_RESPONSE",502)
	var identifier: String = preload("res://backend/network_health.gd").request_id(PackedStringArray(["X-Request-ID: "+str(response.get("request_id",""))]))
	if not identifier.is_empty(): failed.request_id = identifier
	return failed

func rate_track(version_id: String, score: int, key: String) -> Dictionary:
	return await request_api("/track-versions/"+version_id.uri_encode()+"/rating",HTTPClient.METHOD_PUT,{"score":score},key,true)
