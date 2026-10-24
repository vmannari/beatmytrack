extends Node
signal circuit_requested
## Demand-only ranking reads. No timer, race polling or authoritative local scoring.
const Client = preload("res://backend/backend_client.gd")
var client: Node
var _cache: Dictionary = {}
var _pending: Dictionary = {}
var _generation: int = 0

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
	_cache.clear()
	for pending: Dictionary in _pending.values():
		pending.response = {"ok":false,"error":"Account or safety preferences changed"}
		pending.done = true
	_pending.clear()

func scope() -> String:
	return client.base_url()+"/"+str(client.player.get("id",""))

static func valid_profile(data: Variant) -> bool:
	if not data is Dictionary or not Client._whole(data.get("points"),0,12000): return false
	if data.get("world_rank") != null and not Client._whole(data.world_rank,1,2147483647): return false
	if not data.get("results") is Array or data.results.size() > 26: return false
	for row: Variant in data.results:
		if not row is Dictionary or not Client._whole(row.get("points"),0,1000) or not Client._whole(row.get("weekly_place"),1,2147483647) or not Client._whole(row.get("week_start"),0,9007199254740991) or not row.get("counting") is bool: return false
	if not data.get("career") is Dictionary or data.career.size() > 7: return false
	if not data.career.is_empty():
		for key: String in ["peak_rank","peak_week","peak_field","weeks_top100","weeks_no1","victories","season_titles"]:
			if not Client._whole(data.career.get(key),0,9007199254740991): return false
	return true

static func valid_page(data: Variant) -> bool:
	if not data is Dictionary or not data.get("items") is Array or data.items.size() > 50 or not data.get("next_cursor") is String or data.next_cursor.length() > 400: return false
	for row: Variant in data.items:
		if not row is Dictionary or not row.get("name") is String or row.name.length() > 80 or not row.get("player_id") is String or row.player_id.length() > 36 or not Client._whole(row.get("rank"),1,2147483647) or not Client._whole(row.get("points"),0,12000): return false
	return true

func profile(player_id: String = "", force: bool = false) -> Dictionary:
	var endpoint: String = "/ranking/me" if player_id.is_empty() else "/ranking/players/"+player_id.uri_encode()
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
	elif response.ok and not valid_profile(response.data):
		response = {"ok":false,"error":"Invalid ranking response"}
	elif response.ok:
		_cache.erase(identity)
		_cache[identity] = {"at":Time.get_ticks_msec(),"data":response.data.duplicate(true)}
		while _cache.size() > 8: _cache.erase(_cache.keys()[0])
	pending.response = response
	pending.done = true
	if _pending.get(identity) == pending: _pending.erase(identity)
	return response
