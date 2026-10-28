extends RefCounted
## Bounded metadata-only warming. No track compilation, races or account writes.
const MAX_TARGETS: int = 2
const MAX_ACTIVE: int = 2
const MAX_FOREGROUND: int = 1
const REUSE = preload("res://backend/comparison_reuse.gd")
const PREVIEW_LIMIT: int = 3
var cache = preload("res://backend/menu_snapshot_cache.gd").new()
var client: Node
var _generation: int = 0
var _active: int = 0
var _foreground_active: int = 0
var _queue: Array[Dictionary] = []
var _pending: Dictionary = {}
var _finished: Dictionary = {}
var _boards: Dictionary = {}
var _pump_scheduled: bool = false
var _speculated: Dictionary = {}
var _speculative_started: int = 0
var _speculative_used: int = 0
var _cancelled_before_start: int = 0
var _foreground_started: int = 0
var _speculation_enabled: bool = true
var _comparison_flights: Dictionary = {}
var _actor_scope: String = ""
var _requested_scope: String = ""
signal completed(key: String)

func _service_scope(service: Node) -> String:
	if not is_instance_valid(service): return ""
	var actor: Variant = service.get("player")
	return str(service.base_url())+"/"+str(actor.get("id","") if actor is Dictionary else "")+"/"+str(service.test_drivers_available() if service.has_method("test_drivers_available") else false)

func _current_scope() -> bool:
	return is_instance_valid(client) and not _actor_scope.is_empty() and _actor_scope == _service_scope(client)

func configure(service: Node, path: String, scope: String) -> void:
	var actor_scope: String = _service_scope(service)
	if client == service and cache.path == path and _requested_scope == scope and actor_scope == _actor_scope: return
	client = service
	_actor_scope = actor_scope
	_requested_scope = scope
	_generation += 1
	_queue.clear()
	_pending.clear()
	_finished.clear()
	_boards.clear()
	_comparison_flights.clear()
	_speculated.clear()
	_speculative_started = 0
	_speculative_used = 0
	_cancelled_before_start = 0
	_foreground_started = 0
	cache.max_age_seconds = REUSE.MAX_SECONDS
	# Bind disk data to the actual service identity as well as the caller's
	# scope, including the brief interval before account-change callbacks run.
	cache.configure(path,scope+"/actor/"+actor_scope.sha256_text())

func cancel_speculation() -> void:
	_speculation_enabled = false
	var retained: Array[Dictionary] = []
	for job: Dictionary in _queue:
		if job.get("foreground",false): retained.append(job)
		else:
			_pending.erase(job.key)
			_cancelled_before_start += 1
	_queue = retained
	completed.emit("")

func diagnostics() -> Dictionary:
	return {"speculative_started":_speculative_started,"speculative_used":_speculative_used,
		"cancelled_before_start":_cancelled_before_start,"foreground_started":_foreground_started}

func _consumed(identity: String, value: Dictionary) -> Dictionary:
	if value.has("packet") and _speculated.has(identity):
		_speculated.erase(identity)
		_speculative_used += 1
	return value

static func key(version: String, vehicle: String) -> String:
	return JSON.stringify([version,vehicle,VehicleCatalog.config(vehicle).snapshot(),VehicleSimulation.PHYSICS_VERSION,RaceRules.KEY,TrackCompiler.VERSION,Engine.get_version_info().string,RaceComplete.COMPARISON_BINS],"",true).sha256_text()

func prime(entries: Array, vehicle: String) -> void:
	if not _current_scope() or not client.signed_in(): return
	_speculation_enabled = true
	var wanted: Array[Dictionary] = []
	var seen: Dictionary = {}
	for entry: Dictionary in entries:
		var version: String = str(entry.get("version_id",""))
		if version.is_empty(): continue
		var identity: String = key(version,vehicle)
		if seen.has(identity): continue
		seen[identity] = true
		wanted.append({"key":identity,"version":version,"vehicle":vehicle,"generation":_generation})
		if wanted.size() >= MAX_TARGETS: break
	# The current carousel window replaces stale queued speculation. In-flight
	# requests and explicit foreground requests remain owned until completion.
	var retained: Array[Dictionary] = []
	var queued: Dictionary = {}
	for job: Dictionary in _queue:
		if job.get("foreground",false): retained.append(job); queued[job.key] = true
		else:
			_pending.erase(job.key)
			_cancelled_before_start += 1
	_queue = retained
	for job: Dictionary in wanted:
		var stored: Dictionary = peek(job.version,job.vehicle)
		if queued.has(job.key) or _pending.has(job.key) or stored.has("packet") or stored.has("comparison_error"): continue
		_pending[job.key] = true
		_queue.append(job)
	_pump()

func peek(version: String, vehicle: String) -> Dictionary:
	if not _current_scope(): return {}
	var identity: String = key(version,vehicle)
	var cached: Dictionary = cache.read(identity)
	if not cached.is_empty():
		if cached.get("packet") is Dictionary and valid(cached.packet) and REUSE.fresh(cached): return _fresh_board(cached)
	var value: Dictionary = _finished.get(identity,{})
	var age: int = int(Time.get_unix_time_from_system())-int(value.get("_fetched_at",0))
	if value.has("packet") and valid(value.packet) and REUSE.fresh(value): return _fresh_board(value)
	return value if value.has("comparison_error") and age >= 0 and age < REUSE.LEGACY_SECONDS else {}

func _fresh_board(value: Dictionary) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	var age: int = int(Time.get_unix_time_from_system())-int(value.get("_board_fetched_at",value.get("_fetched_at",0)))
	if age < 0 or age >= REUSE.LEGACY_SECONDS:
		result.erase("friends")
		result.erase("board_error")
	return result

func remember_comparison(version: String, vehicle: String, packet: Dictionary, candidates: Array = [], bests: Array = []) -> void:
	if not _current_scope() or not valid(packet): return
	var identity: String = key(version,vehicle)
	var value: Dictionary = _finished.get(identity,cache.read(identity)).duplicate(true)
	value.packet = packet.duplicate(true)
	value._fetched_at = int(Time.get_unix_time_from_system())
	value._candidate_ticks = candidates.duplicate()
	value._best_ticks = bests.duplicate()
	value.erase("comparison_error")
	_finished[identity] = value
	while _finished.size() > 32: _finished.erase(_finished.keys()[0])
	cache.remember(identity,value)

func remember_board(version: String, vehicle: String, rows: Array, error: String) -> void:
	if not _current_scope(): return
	var identity: String = key(version,vehicle)
	var value: Dictionary = _finished.get(identity,cache.read(identity)).duplicate(true)
	value.friends = rows.duplicate(true)
	value.board_error = error
	value._board_fetched_at = int(Time.get_unix_time_from_system())
	_finished[identity] = value
	while _finished.size() > 32: _finished.erase(_finished.keys()[0])
	if value.has("packet"): cache.remember(identity,value)

func comparison(version: String, vehicle: String, race_ticks: int, lap_ticks: int, bests: Array = [], frame: Dictionary = {}) -> Dictionary:
	if not _current_scope(): return {"ok":false,"data":{}}
	var generation: int = _generation
	var value: Dictionary = peek(version,vehicle)
	if not value.has("packet") and pending(version,vehicle): value = await fetch(version,vehicle)
	if generation != _generation or not _current_scope(): return {"ok":false,"data":{}}
	if value.has("packet") and REUSE.matches(value,race_ticks,lap_ticks) and REUSE.same_bests(value,bests):
		_consumed(key(version,vehicle),value)
		return {"ok":true,"data":value.packet.duplicate(true),"cached":true}
	var packet: Dictionary = value.get("packet",{})
	var path: String = "/track-versions/"+version.uri_encode()+"/results-comparison?vehicle_id="+vehicle.uri_encode()+"&bins=%d" % RaceComplete.COMPARISON_BINS
	if race_ticks > 0: path += "&race_ticks=%d" % race_ticks
	if lap_ticks > 0: path += "&lap_ticks=%d" % lap_ticks
	var overlay: bool = not packet.is_empty() and REUSE.fresh(value) and REUSE.same_bests(value,bests) and REUSE.contains_candidates(packet,race_ticks,lap_ticks) and str(packet.get("histogram_key","")).length() == 64
	path += REUSE.frame_query(packet if overlay else frame)
	if overlay: path += "&known_histogram="+str(packet.histogram_key)
	var flight_key: String = str(generation)+path
	if _comparison_flights.has(flight_key):
		var flight: Dictionary = _comparison_flights[flight_key]
		while not flight.done:
			await client.get_tree().process_frame
			if generation != _generation or not _current_scope(): return {"ok":false,"data":{}}
		return flight.response.duplicate(true)
	if _comparison_flights.size() >= 8: return {"ok":false,"data":{}}
	var flight: Dictionary = {"done":false,"response":{}}
	_comparison_flights[flight_key] = flight
	var response: Dictionary = await client.request_api(path,HTTPClient.METHOD_GET,{},"",true)
	if generation != _generation or not _current_scope(): response = {"ok":false,"data":{}}
	if response.get("ok",false) and overlay and REUSE.merge_overlay(response.get("data",{}),packet).is_empty():
		# An incompatible/corrupt omission cannot make the comparison unusable.
		# Retry once without the optional dictionary hint, retaining the frame.
		response = await client.request_api(path.get_slice("&known_histogram=",0),HTTPClient.METHOD_GET,{},"",true)
		if generation != _generation or not _current_scope(): response = {"ok":false,"data":{}}
	if response.get("ok",false):
		var merged: Dictionary = REUSE.merge_overlay(response.get("data",{}),packet)
		if valid(merged):
			response = response.duplicate(true)
			response.data = merged
			remember_comparison(version,vehicle,merged,[race_ticks,lap_ticks],bests)
		else: response = {"ok":false,"data":{}}
	flight.response = response
	flight.done = true
	_comparison_flights.erase(flight_key)
	return response

func pending(version: String, vehicle: String) -> bool:
	return _pending.has(key(version,vehicle))

func board_pending(version: String, vehicle: String) -> bool:
	return _boards.has(key(version,vehicle))

func fetch(version: String, vehicle: String) -> Dictionary:
	if not _current_scope(): return {}
	var identity: String = key(version,vehicle)
	var value: Dictionary = peek(version,vehicle)
	if value.has("packet") or value.has("comparison_error"): return _consumed(identity,value.duplicate(true))
	var generation: int = _generation
	for index: int in range(_queue.size()-1,-1,-1):
		if _queue[index].get("foreground",false) and _queue[index].key != identity:
			var stale: Dictionary = _queue.pop_at(index)
			_pending.erase(stale.key)
			completed.emit(str(stale.key))
	if not _pending.has(identity):
		_pending[identity] = true
		_queue.push_front({"key":identity,"version":version,"vehicle":vehicle,"generation":generation,"foreground":true})
	else:
		for index: int in range(_queue.size()):
			if _queue[index].key == identity:
				var job: Dictionary = _queue.pop_at(index)
				job.foreground = true
				_queue.push_front(job)
				break
	_pump()
	while generation == _generation and _pending.has(identity):
		await completed
	return _consumed(identity,peek(version,vehicle).duplicate(true)) if generation == _generation and _current_scope() else {}

func _pump() -> void:
	if not _current_scope():
		for job: Dictionary in _queue: _pending.erase(job.key)
		_queue.clear()
		return
	if _foreground_active < MAX_FOREGROUND:
		for index: int in range(_queue.size()):
			if not _queue[index].get("foreground",false): continue
			_foreground_active += 1
			_run(_queue.pop_at(index))
			break
	while _active < MAX_ACTIVE and not _queue.is_empty():
		# A newer selected track can use a free background slot while an older
		# foreground request is still in flight; total comparison jobs stay <=3.
		var job: Dictionary = _queue.pop_front()
		if not _speculation_enabled and not job.get("foreground",false):
			_pending.erase(job.key)
			_cancelled_before_start += 1
			continue
		job.requested = job.get("foreground",false)
		job.foreground = false
		_active += 1
		_run(job)

func _run(job: Dictionary) -> void:
	var service: Node = client
	if job.get("foreground",false) or job.get("requested",false): _foreground_started += 1
	else:
		_speculative_started += 1
		_speculated[job.key] = true
		while _speculated.size() > 32: _speculated.erase(_speculated.keys()[0])
	var board: Dictionary = {"done":false,"friends":[],"error":""}
	_board(service,job,board)
	var response: Dictionary = await service.request_api("/track-versions/"+str(job.version).uri_encode()+"/results-comparison?vehicle_id="+str(job.vehicle).uri_encode()+"&bins=%d" % RaceComplete.COMPARISON_BINS,HTTPClient.METHOD_GET,{},"",true)
	if int(job.generation) == _generation and _current_scope():
		var value: Dictionary = {"_fetched_at":int(Time.get_unix_time_from_system())}
		if board.done:
			value.friends = board.friends
			value.board_error = board.error
		if response.get("ok",false) and valid(response.get("data",{})):
			value.packet = response.data
			if board.done: value._board_fetched_at = board.get("at",value._fetched_at)
			cache.remember(job.key,value)
		else: value.comparison_error = "Comparison unavailable"
		_finished[job.key] = value
		while _finished.size() > 32: _finished.erase(_finished.keys()[0])
		_pending.erase(job.key)
	elif int(job.generation) == _generation: _pending.erase(job.key)
	if job.get("foreground",false): _foreground_active -= 1
	else: _active -= 1
	completed.emit(str(job.key))
	_schedule_pump()

func _schedule_pump() -> void:
	if _pump_scheduled or not is_instance_valid(client): return
	_pump_scheduled = true
	# Yield to an actual frame before continuing speculation. HTTP completion
	# callbacks can otherwise keep the deferred-message flush busy for seconds.
	await client.get_tree().process_frame
	_pump_scheduled = false
	_pump()

func _board(service: Node, job: Dictionary, board: Dictionary) -> void:
	_boards[job.key] = job.generation
	var response: Dictionary = await service.request_public("/track-versions/"+str(job.version).uri_encode()+"/leaderboard?vehicle_id="+str(job.vehicle).uri_encode()+"&limit=%d" % PREVIEW_LIMIT,0)
	if response.get("ok",false):
		for item: Dictionary in response.data.get("items",[]):
			board.friends.append({"player":"%d. %s" % [int(item.rank),str(item.display_name)],"country_code":str(item.get("country_code","")),"race_ms":float(item.time_ticks)*1000.0/VehicleSimulation.TICK_RATE})
	else: board.error = str(response.get("error","Unavailable"))
	board.done = true
	board.at = int(Time.get_unix_time_from_system())
	if int(job.generation) == _generation and _current_scope():
		_boards.erase(job.key)
		var value: Dictionary = _finished.get(job.key,{"_fetched_at":int(Time.get_unix_time_from_system())})
		value.friends = board.friends
		value.board_error = board.error
		value._board_fetched_at = board.at
		_finished[job.key] = value
		while _finished.size() > 32: _finished.erase(_finished.keys()[0])
		if value.has("packet"): cache.remember(job.key,value)
		completed.emit(str(job.key))
	elif int(job.generation) == _generation:
		_boards.erase(job.key)
		completed.emit(str(job.key))

static func valid(data: Dictionary) -> bool:
	return data.get("population_scope","") == "all" and data.get("race") is Dictionary and data.get("best_lap") is Dictionary and RaceComplete._valid_distribution(data.race,"race",str(data.get("board_id",""))) and RaceComplete._valid_distribution(data.best_lap,"best_lap",str(data.get("board_id","")))
