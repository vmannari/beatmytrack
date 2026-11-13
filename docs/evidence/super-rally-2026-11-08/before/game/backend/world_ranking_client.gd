extends Node
signal circuit_requested
## Demand-only ranking reads. No timer, race polling or authoritative local scoring.
const Client = preload("res://backend/backend_client.gd")
var client: Node
var _cache: Dictionary = {}
var _pending: Dictionary = {}
var _generation: int = 0
var circuit_vehicle: String = ""
const CAR_IDS: Array[String] = ["compact","pickup","classic","formula","kart","electric","forklift","hovercraft"]

static func multi_supported(adapter: Node) -> bool:
	return supported(adapter) and int(adapter.get("_capabilities").get("world_ranking_version",0)) >= 2

static func supported(adapter: Node) -> bool:
	return is_instance_valid(adapter) and adapter.get("_capabilities") is Dictionary and int(adapter.get("_capabilities").get("world_ranking_version",0)) >= 1

static func circuit_open(adapter: Node) -> bool:
	if not supported(adapter) or not adapter.has_method("server_now"): return false
	var launch: int = int(adapter.get("_capabilities").get("world_ranking_launch_week",0))
	return launch > 0 and int(adapter.server_now()) >= launch

static func for_client(adapter: Node) -> Node:
	var value: Node = adapter.get_node_or_null("WorldRankingClient")
	if value == null:
		value = load("res://backend/world_ranking_client.gd").new()
		value.name = "WorldRankingClient"
		value.client = adapter
		adapter.add_child(value)
	return value

func _ready() -> void:
	if client.has_signal("identity_changed"): client.identity_changed.connect(reset)
	if is_instance_valid(client.get("safety")): client.safety.changed.connect(reset)

func reset() -> void:
	_generation += 1
	circuit_vehicle = ""
	_cache.clear()
	for pending: Dictionary in _pending.values():
		pending.response = {"ok":false,"error":"Account or safety preferences changed"}
		pending.done = true
	_pending.clear()

func scope() -> String:
	return client.base_url()+"/"+str(client.player.get("id",""))

static func valid_profile(data: Variant) -> bool:
	if not data is Dictionary: return false
	var multi: bool = data.get("policy") == "multi-car-circuit-v2"
	var maximum: int = 27900 if multi and data.get("car") == "overall" else 18000 if multi else 12000
	if not Client._whole(data.get("points"),0,maximum): return false
	if multi and not _valid_multi(data): return false
	if data.get("world_rank") != null and not Client._whole(data.world_rank,1,2147483647): return false
	if not data.get("results") is Array or data.results.size() > 26: return false
	for row: Variant in data.results:
		if not row is Dictionary or not Client._whole(row.get("points"),0,1500 if multi else 1000) or not Client._whole(row.get("weekly_place"),1,2147483647) or not Client._whole(row.get("week_start"),0,9007199254740991) or not row.get("counting") is bool: return false
	if not data.get("career") is Dictionary or data.career.size() > 7: return false
	if not data.career.is_empty():
		for key: String in ["peak_rank","peak_week","peak_field","weeks_top100","weeks_no1","victories","season_titles"]:
			if not Client._whole(data.career.get(key),0,9007199254740991): return false
	return true

static func _valid_multi(data: Dictionary) -> bool:
	if data.get("car") != "overall" and not data.get("car") in CAR_IDS: return false
	if not data.get("cars") is Array or data.cars.size() > CAR_IDS.size(): return false
	if not data.get("circuit_cars",[]) is Array or data.get("circuit_cars",[]).size() > CAR_IDS.size() or not data.get("circuit_weights",{}) is Dictionary: return false
	var circuit_cars: Array = []
	for car: Variant in data.get("circuit_cars",[]):
		if not car in CAR_IDS or car in circuit_cars or not Client._whole(data.get("circuit_weights",{}).get(car),10000,12500): return false
		circuit_cars.append(car)
	if data.get("circuit_weights",{}).size() != circuit_cars.size(): return false
	var seen: Array = []
	var weights: Array = []
	var total: int = 0
	for value: Variant in data.cars:
		if not value is Dictionary or not value.get("vehicle_id") in CAR_IDS or value.vehicle_id in seen: return false
		if not Client._whole(value.get("points"),0,18000) or not value.get("counting_weight") in [0,15,40,100]: return false
		if value.counting_weight != 0 and value.counting_weight in weights: return false
		if not Client._whole(value.get("contribution_hundredths"),0,1800000) or value.contribution_hundredths != value.points*value.counting_weight: return false
		if value.get("world_rank") != null and not Client._whole(value.world_rank,1,2147483647): return false
		seen.append(value.vehicle_id)
		weights.append(value.counting_weight)
		total += int(value.contribution_hundredths)
	return data.car != "overall" or total/100 == int(data.points)

static func valid_page(data: Variant) -> bool:
	if not data is Dictionary or not data.get("items") is Array or data.items.size() > 50 or not data.get("next_cursor") is String or data.next_cursor.length() > 400: return false
	var multi: bool = data.get("policy") == "multi-car-circuit-v2"
	if multi and data.get("car") != "overall" and not data.get("car") in CAR_IDS: return false
	var maximum: int = 27900 if multi and data.get("car") == "overall" else 18000 if multi else 12000
	for row: Variant in data.items:
		if not row is Dictionary or not row.get("name") is String or row.name.length() > 80 or not row.get("player_id") is String or row.player_id.length() > 36 or not Client._whole(row.get("rank"),1,2147483647) or not Client._whole(row.get("points"),0,maximum): return false
	return true

func profile(player_id: String = "", force: bool = false, vehicle_id: String = "overall") -> Dictionary:
	if vehicle_id != "overall" and not vehicle_id in CAR_IDS: return {"ok":false,"error":"Unknown ranking car"}
	var endpoint: String = "/ranking/me" if player_id.is_empty() else "/ranking/players/"+player_id.uri_encode()
	if multi_supported(client): endpoint += "?vehicle_id="+vehicle_id.uri_encode()
	var identity: String = scope()+endpoint
	if not force and _cache.has(identity) and Time.get_ticks_msec()-int(_cache[identity].at) < 60000:
		return {"ok":true,"data":_cache[identity].data.duplicate(true)}
	if _pending.has(identity):
		var pending: Dictionary = _pending[identity]
		while not pending.done and is_inside_tree(): await get_tree().process_frame
		return pending.response if pending.done else {"ok":false,"error":"Ranking view closed"}
	if _pending.size() >= 4: return {"ok":false,"error":"Ranking refresh already in progress"}
	var pending: Dictionary = {"done":false,"response":{}}
	_pending[identity] = pending
	var generation: int = _generation
	var response: Dictionary = await client.request_api(endpoint,HTTPClient.METHOD_GET,{},"",true)
	if generation != _generation or identity != scope()+endpoint:
		response = {"ok":false,"error":"Account or safety preferences changed"}
	elif response.ok and (not valid_profile(response.data) or (response.data.get("policy") == "multi-car-circuit-v2" and response.data.get("car") != vehicle_id)):
		response = {"ok":false,"error":"Invalid ranking response"}
	elif response.ok:
		_cache.erase(identity)
		_cache[identity] = {"at":Time.get_ticks_msec(),"data":response.data.duplicate(true)}
		while _cache.size() > 8: _cache.erase(_cache.keys()[0])
	pending.response = response
	pending.done = true
	if _pending.get(identity) == pending: _pending.erase(identity)
	return response
