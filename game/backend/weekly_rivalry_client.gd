extends Node
## Authenticated rivalry adapter. All points and results come from the server.
signal changed
var client: Node
var model := WeeklyRivalry.new()
var busy: bool = false
var error: String = ""
var snapshot_scope: String = ""
var result_ticket: String = ""
var result_state: String = ""
var test_population: bool = false
var _generation: int = 0
var result_polling: bool = false
var _poll_ticket: String = ""
var _poll_started_msec: int = 0
var _next_poll_msec: int = 0

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
	result_ticket = ""
	result_state = ""
	error = ""
	busy = false
	result_polling = false
	_poll_ticket = ""
	_next_poll_msec = 0

static func valid_snapshot(value: Dictionary) -> bool:
	if value.get("state") not in ["not_joined","active","settling","complete"]: return false
	if value.has("test_population") and not value.test_population is bool: return false
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

func refresh() -> void:
	if busy: return
	if snapshot_scope != scope(): reset()
	if not client.signed_in():
		error = "Sign in to join Weekly Rivalry."
		changed.emit()
		return
	await _fetch("/rivalry/current?vehicle_id="+VehicleCatalog.selected.uri_encode()+("&test_population=true" if test_population else ""))

func join() -> void:
	if busy: return
	await _fetch("/rivalry/join",HTTPClient.METHOD_POST,{"vehicle_id":VehicleCatalog.selected,"test_population":test_population})

func _fetch(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}) -> void:
	busy = true
	error = ""
	var original: String = scope()
	var generation: int = _generation
	changed.emit()
	var response: Dictionary = await client.request_api(path,method,payload,client.new_idempotency_key() if method == HTTPClient.METHOD_POST else "",true)
	if generation != _generation or original != scope(): return
	busy = false
	if response.ok and valid_snapshot(response.data):
		model.apply_snapshot(response.data)
		snapshot_scope = original
	else:
		error = "Five eligible tracks are needed before a rivalry can open." if str(response.get("error","")) == "NOT_ENOUGH_ELIGIBLE_TRACKS" else "Rivalry unavailable. Check your connection and try again."
	changed.emit()

func ticket(slot: int) -> Dictionary:
	if busy or model.completed or model.status != "active" or snapshot_scope != scope(): return {}
	var original: String = scope()
	var generation: int = _generation
	var response: Dictionary = await client.request_api("/rivalry/"+model.group_id+"/tickets",HTTPClient.METHOD_POST,{"slot":slot},client.new_idempotency_key(),true)
	if original != scope() or generation != _generation: return {}
	if not response.ok:
		error = str(response.get("error","Race unavailable"))
		changed.emit()
		return {}
	return response.data

func ghost(slot: int, driver: String) -> Dictionary:
	if driver.is_empty() or snapshot_scope != scope(): return {}
	var original: String = scope()
	var generation: int = _generation
	var response: Dictionary = await client.request_api("/rivalry/"+model.group_id+"/tracks/"+str(slot)+"/ghosts/"+driver.uri_encode(),HTTPClient.METHOD_GET,{},"",true)
	if generation != _generation or original != scope() or not response.ok: return {}
	var recording: Variant = response.data.get("recording",{})
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
	var response: Dictionary = await client.request_api("/rivalry/tickets/"+ticket_id+"/result",HTTPClient.METHOD_GET,{},"",true)
	if generation != _generation: return
	result_polling = false
	if original != scope() or result_ticket != ticket_id: return
	var elapsed: int = Time.get_ticks_msec()-_poll_started_msec
	_next_poll_msec = Time.get_ticks_msec()+(500 if elapsed < 15000 else 2000 if elapsed < 60000 else 5000)
	if not response.ok:
		_next_poll_msec = Time.get_ticks_msec()+maxi(5000,int(response.get("retry_after",0))*1000)
		error = "Result saved. Reconnect to verify your rivalry result."
		changed.emit()
		return
	error = ""
	result_state = str(response.data.get("status","upload_pending"))
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
	var response: Dictionary = await client.request_api("/rivalry/"+model.group_id+"/continue",HTTPClient.METHOD_POST,{},client.new_idempotency_key(),true)
	if original != scope() or generation != _generation: return
	if response.ok:
		reset()
		await refresh()
	else:
		error = "Could not continue. Try again."
		changed.emit()
