class_name ChallengesClient
extends Node
## Invitations, retry identity and account fences stay outside the simulation.
signal changed
var client: Node
var cloud: Node
var items: Array[Dictionary] = []
var selected: Dictionary = {}
var folder: String = "received"
var busy: bool = false
var error: String = ""
var result_ticket: String = ""
var result_state: String = ""
var outcome: Dictionary = {}
var _generation: int = 0
var _polling: bool = false
var _next_poll: int = 0
var _failures: int = 0
var _scope: String = ""
var _selection_serial: int = 0
var next_cursor: String = ""
var result_code: String = ""

func scope() -> String:
	return str(client.base_url())+"/"+str(client.player.get("id",""))

func reset() -> void:
	_generation += 1
	_selection_serial += 1
	items.clear()
	selected = {}
	busy = false
	error = ""
	result_ticket = ""
	result_state = ""
	outcome = {}
	_polling = false
	_next_poll = 0
	_failures = 0
	_scope = scope()
	next_cursor = ""
	result_code = ""

static func code_from(value: String) -> String:
	var code: String = value.strip_edges().get_slice("?",0).get_slice("#",0).trim_suffix("/").get_file().replace("-","").replace(" ","").to_upper()
	return code if code.length() == 16 and code.is_valid_hex_number(false) else ""

static func valid_snapshot(value: Variant) -> bool:
	if not value is Dictionary or not value.has_all(["id","code","mode","state","entry","manifest","standings","vehicle_id","ends_at","server_now","creator_id","creator","joined","self_id","share_url"]): return false
	for field: String in ["id","code","creator_id","creator","share_url"]:
		if not preload("res://backend/backend_client.gd")._text(value.get(field)): return false
	if not value.self_id is String: return false
	if code_from(str(value.code)) != value.code or value.mode not in ["beat","group"] or value.state not in ["active","settling","complete","cancelled"] or value.vehicle_id not in VehicleCatalog.IDS or not value.joined is bool: return false
	if not value.entry is Dictionary or not value.entry.has_all(["name","version_id","track_id","content_hash","points"]): return false
	for field: String in ["name","version_id","track_id","content_hash"]:
		if not preload("res://backend/backend_client.gd")._text(value.entry.get(field)): return false
	if not value.entry.points is Array or value.entry.points.size() < 2 or value.entry.points.size() > 4096: return false
	for point: Variant in value.entry.points:
		if not point is Array or point.size() != 2 or not (point[0] is float or point[0] is int) or not (point[1] is float or point[1] is int) or not is_finite(float(point[0])) or not is_finite(float(point[1])): return false
	if not value.manifest is Dictionary or int(value.manifest.get("laps",0)) != 5 or not value.manifest.get("tick_rate") is float and not value.manifest.get("tick_rate") is int or int(value.manifest.tick_rate) <= 0: return false
	if not value.standings is Array or value.standings.is_empty() or value.standings.size() > 20: return false
	if value.mode == "beat" and (not preload("res://backend/backend_client.gd")._whole(value.get("target_ticks"),1,216000) or not preload("res://backend/backend_client.gd")._whole(value.get("target_ms"),1)): return false
	if value.has("attempt_limit") or value.has("attempts_used") or value.has("attempts_remaining"):
		if not value.has_all(["attempt_limit","attempts_used","attempts_remaining"]): return false
		var limit: Variant = value.attempt_limit
		if limit != null and (not preload("res://backend/backend_client.gd")._whole(limit,1,5) or int(limit) not in [1,3,5]): return false
		if not preload("res://backend/backend_client.gd")._whole(value.attempts_used): return false
		if limit == null:
			if value.attempts_remaining != null: return false
		elif not preload("res://backend/backend_client.gd")._whole(value.attempts_remaining,0,int(limit)) or int(value.attempts_used)+int(value.attempts_remaining) != int(limit): return false
	var seen: Dictionary = {}
	for row: Variant in value.standings:
		if not row is Dictionary or not row.has_all(["id","name","ticks","ms","rank","run_id"]) or seen.has(str(row.id)): return false
		if not preload("res://backend/backend_client.gd")._text(row.id) or not preload("res://backend/backend_client.gd")._text(row.name): return false
		if row.ticks == null and (row.ms != null or row.rank != null or row.run_id != null): return false
		seen[str(row.id)] = true
		if row.ticks != null and (not preload("res://backend/backend_client.gd")._whole(row.ticks,1,216000) or not preload("res://backend/backend_client.gd")._whole(row.rank,1,20) or not preload("res://backend/backend_client.gd")._whole(row.ms,1)): return false
	if value.joined != seen.has(str(value.self_id)): return false
	return preload("res://backend/backend_client.gd")._whole(value.ends_at) and preload("res://backend/backend_client.gd")._whole(value.server_now)

func _request(path: String, method: HTTPClient.Method = HTTPClient.METHOD_GET, payload: Dictionary = {}, authorized: bool = true) -> Dictionary:
	if _scope != scope(): reset()
	var original: String = scope()
	var generation: int = _generation
	var key: String = ""
	var saved: Dictionary = {}
	var signature: String = ""
	var path_to_keys: String = ""
	if method == HTTPClient.METHOD_POST:
		path_to_keys = cloud.cache_root().path_join("players").path_join(str(client.player.get("id","")).sha256_text()).path_join("challenge-operations.json")
		saved = cloud._read(path_to_keys)
		if saved.has("_read_error"): return {"ok":false,"error":"Could not recover challenge creation. Original retry data was preserved."}
		signature = JSON.stringify([path,payload],"",true).sha256_text()
		key = str(saved.get(signature,client.new_operation_key()))
		saved[signature] = key
		if not cloud._write(path_to_keys,saved): return {"ok":false,"error":"Could not save challenge retry. Check available storage."}
	var response: Dictionary = await client.request_api(path,method,payload,key,authorized)
	if generation != _generation or original != scope(): return {"ok":false,"error":"Account changed"}
	if response.get("ok",false) and not signature.is_empty():
		saved = cloud._read(path_to_keys)
		if not saved.has("_read_error"):
			saved.erase(signature)
			cloud._write(path_to_keys,saved)
	return response

func refresh(append: bool = false) -> void:
	if busy: return
	if not client.signed_in():
		items.clear()
		changed.emit()
		return
	busy = true
	changed.emit()
	var requested_folder: String = folder
	var response: Dictionary = await _request("/challenges?folder="+folder+("&cursor="+next_cursor.uri_encode() if append and not next_cursor.is_empty() else ""))
	busy = false
	if requested_folder != folder: return
	if response.get("ok",false) and response.data.get("items") is Array and response.data.items.size() <= 50:
		var incoming: Array[Dictionary] = []
		for item: Variant in response.data.items:
			if not valid_snapshot(item):
				error = "Challenge list could not be loaded. Try again."
				changed.emit()
				return
			incoming.append(item)
		if append: items.append_array(incoming)
		else: items = incoming
		for item: Dictionary in incoming:
			if str(item.code) == str(selected.get("code","")): selected = item
		next_cursor = str(response.data.next_cursor) if response.data.get("next_cursor") is String else ""
		error = ""
	else: error = friendly(str(response.get("error","")))
	changed.emit()
	if not selected.is_empty() and not items.any(func(item: Dictionary) -> bool: return str(item.code) == str(selected.code)):
		await open(str(selected.code))

func open(value: String) -> void:
	var code: String = code_from(value)
	if code.is_empty():
		error = "Enter a challenge code or invitation link."
		changed.emit()
		return
	_selection_serial += 1
	var serial: int = _selection_serial
	busy = true
	changed.emit()
	var response: Dictionary = await _request("/challenges/"+code+("/me" if client.signed_in() else ""),HTTPClient.METHOD_GET,{},client.signed_in())
	if serial != _selection_serial: return
	busy = false
	if response.get("ok",false) and valid_snapshot(response.data):
		selected = response.data
		error = ""
	else: error = friendly(str(response.get("error","")))
	changed.emit()

func create_challenge(payload: Dictionary) -> void:
	await _mutate("/challenges",payload)

func join() -> void:
	if selected.is_empty(): return
	await _mutate("/challenges/"+str(selected.code)+"/join")

func rematch() -> void:
	if selected.is_empty(): return
	await _mutate("/challenges/"+str(selected.code)+"/rematch",{"duration_seconds":604800})

func cancel() -> void:
	if selected.is_empty(): return
	await _mutate("/challenges/"+str(selected.code)+"/cancel")

func _mutate(path: String, payload: Dictionary = {}) -> void:
	if busy: return
	busy = true
	error = ""
	changed.emit()
	var response: Dictionary = await _request(path,HTTPClient.METHOD_POST,payload)
	busy = false
	if response.get("ok",false) and valid_snapshot(response.data): selected = response.data
	else: error = friendly(str(response.get("error","")))
	changed.emit()

func source(version: String, vehicle: String, ticket_id: String = "") -> Dictionary:
	var response: Dictionary = await _request("/challenges/sources?version_id="+version.uri_encode()+"&vehicle_id="+vehicle.uri_encode()+("&ticket_id="+ticket_id.uri_encode() if not ticket_id.is_empty() else ""))
	return response.data if response.get("ok",false) else {"status":"unavailable","error":friendly(str(response.get("error","")))}

func ticket() -> Dictionary:
	if selected.is_empty() or not selected.get("joined",false) or selected.state != "active": return {}
	var response: Dictionary = await _request("/challenges/"+str(selected.code)+"/tickets",HTTPClient.METHOD_POST)
	if not response.get("ok",false):
		error = friendly(str(response.get("error","")))
		changed.emit()
		return {}
	if int(response.data.get("expires_at",0)) <= client.server_now():
		error = "Race invitation expired. Try again for a fresh start."
		changed.emit()
		return {}
	for field: String in ["attempt_limit","attempts_used","attempts_remaining"]:
		if response.data.has(field): selected[field] = response.data[field]
	return response.data

func ghost() -> Dictionary:
	if selected.is_empty(): return {}
	var response: Dictionary = await _request("/challenges/"+str(selected.code)+"/ghost",HTTPClient.METHOD_GET,{},false)
	if not response.get("ok",false): return {}
	return preload("res://backend/weekly_rivalry_client.gd")._validate_ghost(response.data.get("recording",{}))

func begin_result(ticket_id: String) -> void:
	result_ticket = ticket_id
	result_code = str(selected.get("code",""))
	result_state = "upload_pending"
	outcome = {}
	_next_poll = 0
	_failures = 0

func poll_result() -> void:
	if _polling or result_ticket.is_empty() or result_state in ["verified","rejected","expired"] or Time.get_ticks_msec() < _next_poll: return
	var expected: String = result_ticket
	var original: String = scope()
	_polling = true
	var response: Dictionary = await _request("/challenge-results/"+expected)
	_polling = false
	if expected != result_ticket or original != scope(): return
	_next_poll = Time.get_ticks_msec()+maxi(1000,int(response.get("data",{}).get("poll_after_ms",2500)))
	if not response.get("ok",false):
		_failures = mini(_failures+1,5)
		_next_poll = Time.get_ticks_msec()+mini(60000,2500*int(pow(2,_failures)))
		error = "Result saved. Reconnect to verify it."
	elif valid_snapshot(response.data.get("challenge")):
		if str(selected.get("code","")) == result_code: selected = response.data.challenge
		result_state = str(response.data.get("status","upload_pending"))
		outcome = response.data.get("outcome",{}) if response.data.get("outcome") is Dictionary else {}
		error = ""
		if result_state == "failed":
			if response.data.get("failure_code") == "verifier_unavailable":
				result_state = "retry_pending"
				_next_poll = Time.get_ticks_msec()+15000
				error = "Your race is saved. Verification will retry."
			else:
				result_state = "rejected"
				error = "This race could not be verified."
		elif result_state in ["rejected","expired"]: error = "This race did not enter the challenge standings."
	else: error = "Could not load challenge results. Try again."
	changed.emit()

static func friendly(message: String) -> String:
	if message in ["NETWORK_ERROR","REQUEST_START_FAILED","NOT_CONFIGURED"]: return "Challenges unavailable. Check your connection and try again."
	if message in ["DATABASE_UNAVAILABLE","STORAGE_UNAVAILABLE","INVALID_RESPONSE"]: return "Challenges unavailable. Try again."
	if message == "Not Found": return "Challenges are not available yet."
	if message == "SIGN_IN_REQUIRED": return "Sign in to create or join a challenge."
	return message if not message.is_empty() else "Challenges unavailable. Try again."
