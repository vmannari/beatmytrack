extends RefCounted
## Bounded metadata-only warming. No track compilation, races or account writes.
const MAX_TARGETS: int = 6
const MAX_ACTIVE: int = 2
const MAX_FOREGROUND: int = 1
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
signal completed(key: String)

func configure(service: Node, path: String, scope: String) -> void:
	if client == service and cache.path == path and cache.scope == scope: return
	client = service
	_generation += 1
	_queue.clear()
	_pending.clear()
	_finished.clear()
	_boards.clear()
	cache.configure(path,scope)

static func key(version: String, vehicle: String) -> String:
	return JSON.stringify([version,vehicle,VehicleCatalog.config(vehicle).snapshot(),VehicleSimulation.PHYSICS_VERSION,RaceRules.KEY,TrackCompiler.VERSION,Engine.get_version_info().string,RaceComplete.COMPARISON_BINS],"",true).sha256_text()

func prime(entries: Array, vehicle: String) -> void:
	if not is_instance_valid(client) or not client.signed_in(): return
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
		else: _pending.erase(job.key)
	_queue = retained
	for job: Dictionary in wanted:
		var stored: Dictionary = peek(job.version,job.vehicle)
		if queued.has(job.key) or _pending.has(job.key) or stored.has("packet") or stored.has("comparison_error"): continue
		_pending[job.key] = true
		_queue.append(job)
	_pump()

func peek(version: String, vehicle: String) -> Dictionary:
	var identity: String = key(version,vehicle)
	var cached: Dictionary = cache.read(identity)
	if not cached.is_empty():
		if cached.get("packet") is Dictionary and valid(cached.packet): return cached
		cache.forget(identity)
	var value: Dictionary = _finished.get(identity,{})
	var age: int = int(Time.get_unix_time_from_system())-int(value.get("_fetched_at",0))
	return value if age >= 0 and age < cache.max_age_seconds else {}

func pending(version: String, vehicle: String) -> bool:
	return _pending.has(key(version,vehicle))

func board_pending(version: String, vehicle: String) -> bool:
	return _boards.has(key(version,vehicle))

func fetch(version: String, vehicle: String) -> Dictionary:
	var identity: String = key(version,vehicle)
	var value: Dictionary = peek(version,vehicle)
	if value.has("packet") or value.has("comparison_error"): return value.duplicate(true)
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
	return peek(version,vehicle).duplicate(true) if generation == _generation else {}

func _pump() -> void:
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
		job.foreground = false
		_active += 1
		_run(job)

func _run(job: Dictionary) -> void:
	var service: Node = client
	var board: Dictionary = {"done":false,"friends":[],"error":""}
	_board(service,job,board)
	var response: Dictionary = await service.request_api("/track-versions/"+str(job.version).uri_encode()+"/results-comparison?vehicle_id="+str(job.vehicle).uri_encode()+"&bins=%d" % RaceComplete.COMPARISON_BINS,HTTPClient.METHOD_GET,{},"",true)
	if int(job.generation) == _generation:
		var value: Dictionary = {"_fetched_at":int(Time.get_unix_time_from_system())}
		if board.done:
			value.friends = board.friends
			value.board_error = board.error
		if response.get("ok",false) and valid(response.get("data",{})):
			value.packet = response.data
			cache.remember(job.key,value)
		else: value.comparison_error = "Comparison unavailable"
		_finished[job.key] = value
		while _finished.size() > 32: _finished.erase(_finished.keys()[0])
		_pending.erase(job.key)
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
	var response: Dictionary = await service.request_public("/track-versions/"+str(job.version).uri_encode()+"/leaderboard?vehicle_id="+str(job.vehicle).uri_encode(),0)
	if response.get("ok",false):
		for item: Dictionary in response.data.get("items",[]):
			board.friends.append({"player":"%d. %s" % [int(item.rank),str(item.display_name)],"country_code":str(item.get("country_code","")),"race_ms":float(item.time_ticks)*1000.0/VehicleSimulation.TICK_RATE})
	else: board.error = str(response.get("error","Unavailable"))
	board.done = true
	if int(job.generation) == _generation:
		_boards.erase(job.key)
		var value: Dictionary = _finished.get(job.key,{"_fetched_at":int(Time.get_unix_time_from_system())})
		value.friends = board.friends
		value.board_error = board.error
		_finished[job.key] = value
		while _finished.size() > 32: _finished.erase(_finished.keys()[0])
		if value.has("packet"): cache.remember(job.key,value)
		completed.emit(str(job.key))

static func valid(data: Dictionary) -> bool:
	return data.get("population_scope","") == "all" and data.get("race") is Dictionary and data.get("best_lap") is Dictionary and RaceComplete._valid_distribution(data.race,"race",str(data.get("board_id",""))) and RaceComplete._valid_distribution(data.best_lap,"best_lap",str(data.get("board_id","")))
