extends Node
## Authenticated rivalry adapter. All points and results come from the server.
signal changed
var client: Node
var model := WeeklyRivalry.new()
var busy: bool = false
var error: String = ""
var snapshot_scope: String = ""
var request_scope: String = ""
var result_ticket: String = ""
var result_state: String = ""
var test_population: bool = false
var _generation: int = 0
var result_polling: bool = false
var _poll_failures: int = 0
var _poll_ticket: String = ""
var _poll_started_msec: int = 0
var _next_poll_msec: int = 0
var _ghost_cache: Dictionary = {}
var _ghost_pending: Dictionary = {}
var cache_directory: String = ""
var cached_snapshot: bool = false
var snapshot_cache = preload("res://backend/menu_snapshot_cache.gd").new()
var _last_refresh_msec: int = -60000
const REFRESH_INTERVAL_MSEC: int = 30000

func _cache_scope() -> String:
	return scope()+"/"+VehicleSimulation.PHYSICS_VERSION+"/"+RaceRules.KEY+"/"+TrackCompiler.VERSION+"/"+JSON.stringify(HandlingSelection.config().snapshot(),"",true).sha256_text()

func _configure_cache() -> void:
	snapshot_cache.max_entries = 1
	snapshot_cache.max_age_seconds = 86400
	var identity: String = _cache_scope()
	snapshot_cache.configure(cache_directory.path_join(identity.sha256_text()+".json") if not cache_directory.is_empty() else "",identity)

func _restore_snapshot() -> void:
	if has_snapshot() or not client.signed_in(): return
	_configure_cache()
	var saved: Dictionary = snapshot_cache.read("current")
	var value: Variant = saved.get("snapshot")
	if not value is Dictionary or not valid_snapshot(value) or value.get("state") == "not_joined": return
	if str(value.get("self_id","")) != str(client.player.get("id","")) or str(value.get("vehicle_id","")) != VehicleCatalog.selected or bool(value.get("test_population",false)) != test_population: return
	var age: int = maxi(0,int(Time.get_unix_time_from_system())-int(saved.get("received_at",0)))
	var remaining: int = maxi(0,int(value.get("ends_at",0))-int(value.get("server_now",0))-age)
	if value.state == "active" and remaining == 0: return
	value.remaining_seconds = remaining
	model.apply_snapshot(value)
	snapshot_scope = scope()
	cached_snapshot = true

func _remember_snapshot(value: Dictionary) -> void:
	_configure_cache()
	if value.get("state") == "not_joined":
		snapshot_cache.forget("current")
	else:
		snapshot_cache.remember("current",{"snapshot":value,"received_at":int(Time.get_unix_time_from_system())})

func scope() -> String:
	return str(client.base_url())+"/"+str(client.player.get("id",""))+"/"+VehicleCatalog.selected+("/test" if test_population else "/real")

func set_test_population(enabled: bool) -> void:
	if enabled == test_population: return
	test_population = enabled
	reset()
	changed.emit()

func reset() -> void:
	_generation += 1
	model = WeeklyRivalry.new()
	snapshot_scope = ""
	request_scope = ""
	result_ticket = ""
	result_state = ""
	error = ""
	busy = false
	result_polling = false
	_poll_ticket = ""
	_next_poll_msec = 0
	_ghost_cache.clear()
	_ghost_pending.clear()
	cached_snapshot = false
	_last_refresh_msec = -60000

static func valid_snapshot(value: Dictionary) -> bool:
	if value.get("state") not in ["not_joined","active","settling","complete"]: return false
	if value.has("test_population") and not value.test_population is bool: return false
	if value.has("automatic_test_drivers") and not value.automatic_test_drivers is bool: return false
	if value.get("state") == "not_joined": return value.has_all(["week","ends_at","server_now"])
	if not value.has_all(["group_id","self_id","week","tracks","standings"]): return false
	if not value.tracks is Array or value.tracks.size() != 5 or not value.standings is Array or value.standings.is_empty() or value.standings.size() > 20: return false
	var self_found: bool = false
	for row: Variant in value.standings:
		if not row is Dictionary or not row.has_all(["id","name","points","rank"]): return false
		if row.has("is_test_driver") and not row.is_test_driver is bool: return false
		if row.id == value.self_id: self_found = true
	for track: Variant in value.tracks:
		if not track is Dictionary or not track.has_all(["board_id","entry","entries"]) or not track.get("entry") is Dictionary or not track.get("entries") is Array: return false
		if not track.entry.has_all(["name","version_id","content_hash","points","creator","track_id"]): return false
		if track.entries.size() != value.standings.size(): return false
		for row: Variant in track.entries:
			if not row is Dictionary or not row.has_all(["id","name","ms","rank","points"]): return false
	return self_found

static func valid_outcome(value: Dictionary) -> bool:
	if not value.has_all(["improved","before","after","overall_before","overall_after","points_delta","ms","beaten"]): return false
	if not value.improved is bool or not value.beaten is Array or value.beaten.size() > 19: return false
	if not (value.ms is float or value.ms is int) or not is_finite(float(value.ms)) or float(value.ms) <= 0.0: return false
	if not (value.points_delta is float or value.points_delta is int) or not is_finite(float(value.points_delta)) or float(value.points_delta) < 0.0 or float(value.points_delta) > 30.0: return false
	for key: String in ["before","after","overall_before","overall_after"]:
		if not value[key] is Dictionary or not value[key].has_all(["id","name","rank","points"]): return false
	for row: Variant in value.beaten:
		if not row is Dictionary or not row.has_all(["id","name","rank","ms"]): return false
	return true

func has_snapshot() -> bool:
	return model.sample or (snapshot_scope == scope() and model.received_msec > 0 and (not model.tracks.is_empty() or not busy))

func refresh(force: bool = true) -> void:
	# Development rivalries use the server capability automatically. Release
	# and ordinary services retain the real-player population.
	if OS.is_debug_build() and client.has_method("test_drivers_available"):
		var automatic: bool = client.test_drivers_available()
		if automatic != test_population:
			test_population = automatic
			reset()
	if busy and request_scope == scope(): return
	if busy: reset()
	if snapshot_scope != scope(): reset()
	if not client.signed_in():
		error = "Sign in to join Weekly Rivalry."
		changed.emit()
		return
	_restore_snapshot()
	if not force and not cached_snapshot and has_snapshot() and Time.get_ticks_msec()-_last_refresh_msec < REFRESH_INTERVAL_MSEC: return
	await _fetch("/rivalry/current?vehicle_id="+VehicleCatalog.selected.uri_encode()+("&test_population=true" if test_population else ""))

func join() -> void:
	if busy: return
	await _fetch("/rivalry/join",HTTPClient.METHOD_POST,{"vehicle_id":VehicleCatalog.selected,"test_population":test_population,"automatic_test_drivers":test_population})

func _fetch(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}) -> void:
	busy = true
	error = ""
	var original: String = scope()
	var generation: int = _generation
	request_scope = original
	changed.emit()
	var response: Dictionary = await client.request_api(path,method,payload,client.new_operation_key() if method == HTTPClient.METHOD_POST else "",true)
	if generation != _generation or original != scope(): return
	busy = false
	request_scope = ""
	if response.ok and valid_snapshot(response.data):
		model.apply_snapshot(response.data)
		snapshot_scope = original
		cached_snapshot = false
		_last_refresh_msec = Time.get_ticks_msec()
		_remember_snapshot(response.data)
		var needs_enrollment: bool = model.status == "not_joined" or (model.status == "active" and not bool(response.data.get("automatic_test_drivers",false)))
		if test_population and needs_enrollment and path != "/rivalry/join":
			await join()
			return
	else:
		error = "Five eligible tracks are needed before a rivalry can open." if str(response.get("error","")) == "NOT_ENOUGH_ELIGIBLE_TRACKS" else "Rivalry unavailable. Check your connection and try again."
	changed.emit()

func ticket(slot: int) -> Dictionary:
	if busy or cached_snapshot or model.completed or model.status != "active" or snapshot_scope != scope(): return {}
	var original: String = scope()
	var generation: int = _generation
	var response: Dictionary = await client.request_api("/rivalry/"+model.group_id+"/tickets",HTTPClient.METHOD_POST,{"slot":slot},client.new_operation_key(),true)
	if original != scope() or generation != _generation: return {}
	if not response.ok:
		error = str(response.get("error","Race unavailable"))
		changed.emit()
		return {}
	return response.data

func _ghost_key(slot: int, driver: String) -> String:
	var run_id: String = ""
	for row: Dictionary in model.tracks[slot].get("entries",[]):
		if str(row.get("driver_id",row.get("id",""))) == driver: run_id = str(row.get("run_id",""))
	return "" if run_id.is_empty() else scope()+"/"+model.group_id+"/"+str(slot)+"/"+driver+"/"+run_id

func cached_ghost(slot: int, driver: String) -> Dictionary:
	var value: Dictionary = _ghost_cache.get(_ghost_key(slot,driver),{})
	return value.get("recording",{}) if snapshot_scope == scope() and Time.get_ticks_msec()-int(value.get("at",-60000)) < 30000 else {}

func prefetch_ghost(slot: int, driver: String) -> void:
	var key: String = _ghost_key(slot,driver)
	if key.is_empty() or _ghost_pending.has(key) or not cached_ghost(slot,driver).is_empty(): return
	_ghost_pending[key] = true
	await ghost(slot,driver)
	_ghost_pending.erase(key)

func ghost(slot: int, driver: String) -> Dictionary:
	if driver.is_empty() or snapshot_scope != scope(): return {}
	var original: String = scope()
	var generation: int = _generation
	var cache_key: String = _ghost_key(slot,driver)
	var run_id: String = cache_key.get_slice("/",cache_key.get_slice_count("/")-1)
	var cached: Dictionary = cached_ghost(slot,driver)
	if not cached.is_empty(): return cached
	var response: Dictionary = await client.request_api("/rivalry/"+model.group_id+"/tracks/"+str(slot)+"/ghosts/"+driver.uri_encode(),HTTPClient.METHOD_GET,{},"",true)
	if generation != _generation or original != scope(): return {}
	if not response.ok:
		_ghost_cache.erase(cache_key)
		return {}
	var checked: Variant = await client._background(_validate_ghost.bind(response.data.get("recording",{})))
	if generation != _generation or original != scope() or not checked is Dictionary or checked.is_empty(): return {}
	var recording: Dictionary = checked
	if not run_id.is_empty() and str(response.data.get("run_id","")) == run_id:
		_ghost_cache.erase(cache_key)
		_ghost_cache[cache_key] = {"recording":recording,"at":Time.get_ticks_msec(),"bytes":recording.poses.size()*200}
		var size: int = 0
		for value: Dictionary in _ghost_cache.values(): size += int(value.bytes)
		while _ghost_cache.size() > 8 or size > 8388608:
			var oldest: String = str(_ghost_cache.keys()[0])
			size -= int(_ghost_cache[oldest].bytes)
			_ghost_cache.erase(oldest)
	return recording

static func _validate_ghost(recording: Variant) -> Dictionary:
	if not recording is Dictionary or not recording.has_all(["poses","ticks"]) or not recording.poses is Array or recording.poses.size() < 2 or recording.poses.size() > 36007: return {}
	var previous: float = -1.0
	for pose: Variant in recording.poses:
		if not pose is Array or pose.size() != 7: return {}
		for number: Variant in pose:
			if not (number is float or number is int) or not is_finite(float(number)): return {}
		if float(pose[0]) <= previous: return {}
		previous = float(pose[0])
	if not (recording.ticks is float or recording.ticks is int) or not is_finite(float(recording.ticks)): return {}
	if float(recording.ticks) <= 0 or float(recording.ticks) > PersonalGhostRun.MAX_TICKS or previous != float(recording.ticks) or float(recording.poses[0][0]) != 0.0: return {}
	return recording

func poll_result() -> void:
	if busy or result_polling or result_ticket.is_empty() or snapshot_scope != scope(): return
	var current_msec: int = Time.get_ticks_msec()
	if _poll_ticket != result_ticket:
		_poll_ticket = result_ticket
		_poll_started_msec = current_msec
		_next_poll_msec = 0
	if current_msec < _next_poll_msec: return
	var original: String = scope()
	var ticket_id: String = result_ticket
	var generation: int = _generation
	result_polling = true
	var recent: Dictionary = client.recent_run(ticket_id)
	var response: Dictionary = {"ok":true,"status":200,"data":recent} if not recent.is_empty() and recent.has("outcome") else await client.request_api("/rivalry/tickets/"+ticket_id+"/result",HTTPClient.METHOD_GET,{},"",true)
	if generation != _generation: return
	result_polling = false
	if original != scope() or result_ticket != ticket_id: return
	var elapsed: int = Time.get_ticks_msec()-_poll_started_msec
	var delay: int = maxi(int(response.data.get("poll_after_ms",2500)),1000 if elapsed < 10000 else 2500 if elapsed < 60000 else 5000)
	_next_poll_msec = Time.get_ticks_msec()+delay+int(Crypto.new().generate_random_bytes(1)[0])
	if not response.ok:
		_poll_failures = mini(6,_poll_failures+1)
		var backoff: int = maxi(int(response.get("retry_after",0))*1000,mini(60000,5000*int(pow(2,_poll_failures-1))))
		_next_poll_msec = Time.get_ticks_msec()+backoff+int(Crypto.new().generate_random_bytes(1)[0])*10
		error = "Result saved. Reconnect to verify your rivalry result."
		changed.emit()
		return
	error = ""
	_poll_failures = 0
	result_state = str(response.data.get("status","upload_pending"))
	if result_state == "failed" and response.data.get("failure_code") == "verifier_unavailable":
		result_state = "retry_pending"
		error = "Your race is saved. Verification will retry when the service recovers."
		_next_poll_msec = Time.get_ticks_msec()+15000+int(Crypto.new().generate_random_bytes(1)[0])*10
		changed.emit()
		return
	if result_state == "verified" and response.data.get("outcome") is Dictionary and valid_outcome(response.data.outcome):
		var outcome: Dictionary = response.data.outcome
		var index: int = int(response.data.slot)
		# Confirm feedback as soon as its proof arrives. Refresh the full board
		# afterwards; that extra request must not hold the result screen pending.
		model.apply_outcome(outcome,index)
		changed.emit()
		await _fetch("/rivalry/"+model.group_id)
		if original != scope() or generation != _generation: return
	elif result_state == "verified":
		model.last_result = {"ms":model.last_result.get("ms",0)}
		error = "Result details unavailable. Refresh Rivalry to check your standings."
		changed.emit()
	elif result_state in ["rejected","failed","expired"]:
		model.last_result = {"ms":model.last_result.get("ms",0)}
		error = "This race was not verified. Your weekly best is unchanged."
		changed.emit()

func continue_week() -> void:
	if busy or not model.completed: return
	var original: String = scope()
	var generation: int = _generation
	var response: Dictionary = await client.request_api("/rivalry/"+model.group_id+"/continue",HTTPClient.METHOD_POST,{},client.new_operation_key(),true)
	if original != scope() or generation != _generation: return
	if response.ok:
		_configure_cache()
		snapshot_cache.forget("current")
		reset()
		await refresh()
	else:
		error = "Could not continue. Try again."
		changed.emit()
