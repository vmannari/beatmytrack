extends Node
## Account-scoped, bounded News reads. No timers or background activation here.
signal changed
var client: Node
var items: Array = []
var friends: Array = []
var next_cursor: String = ""
var refreshing: bool = false
var busy: bool = false
var error: String = ""
var checked_day: int = -1
var _scope: String = ""
var _epoch: int = 0
var _fetched_at: int = -60001
var _friends_at: int = -60001
var _publications: Array[Dictionary] = []
## Read markers are local to this device and isolated by account/server.
var read_state_path: String = "user://news_read_state.cfg"
var _read_scope: String = ""
var _read_ids: Array[String] = []
const READ_LIMIT: int = 1000

func scope() -> String:
	return client.base_url()+"/"+str(client.player.get("id",""))

func _load_read_scope(examples: bool) -> void:
	var current: String = "examples" if examples else scope()
	if current == _read_scope: return
	_read_scope = current
	_read_ids.clear()
	var state := ConfigFile.new()
	if state.load(read_state_path) != OK: return
	var saved: Variant = state.get_value("read",current.sha256_text(),[])
	if saved is Array or saved is PackedStringArray:
		for id: Variant in saved:
			if id is String and not id.is_empty() and id.length() <= 256 and not _read_ids.has(id):
				_read_ids.append(id)
				if _read_ids.size() >= READ_LIMIT: break

func story_read(id: String, examples: bool = false) -> bool:
	_load_read_scope(examples)
	return _read_ids.has(id)

func mark_story_read(id: String, examples: bool = false) -> void:
	if id.is_empty() or id.length() > 256: return
	_load_read_scope(examples)
	if _read_ids.has(id): return
	_read_ids.append(id)
	if _read_ids.size() > READ_LIMIT: _read_ids.pop_front()
	var state := ConfigFile.new()
	state.load(read_state_path)
	state.set_value("read",_read_scope.sha256_text(),_read_ids)
	var error_code: Error = state.save(read_state_path)
	if error_code != OK: push_warning("Could not save newspaper read status: "+str(error_code))

func identity_changed() -> void:
	if _scope == scope(): return
	_scope = scope()
	_epoch += 1
	items.clear()
	_publications.clear()
	friends.clear()
	next_cursor = ""
	refreshing = false
	busy = false
	error = ""
	checked_day = -1
	_fetched_at = -60001
	_friends_at = -60001
	changed.emit()

func remember_publications(receipts: Array[Dictionary]) -> void:
	identity_changed()
	if not client.signed_in(): return
	var own: Array[Dictionary] = []
	var versions: Dictionary = {}
	var stamp: int = client.server_now()
	if stamp <= 0: stamp = int(Time.get_unix_time_from_system())
	for value: Dictionary in receipts:
		if value.get("scope") != scope(): continue
		if versions.has(str(value.version_id)): continue
		versions[str(value.version_id)] = true
		var receipt: Dictionary = value.receipt
		var published: int = int(receipt.get("published_at",stamp))
		if published < stamp-90*86400: continue
		own.append({"id":"publication:"+str(value.version_id),"kind":"track_published","version_id":value.version_id,"track_name":str(value.name),"created_at":published,"creator_id":str(client.player.get("id","")),"track_points":receipt.get("points",[])})
	own.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.created_at > b.created_at if a.created_at != b.created_at else str(a.id) > str(b.id))
	own = own.slice(0,30)
	if own == _publications: return
	_publications = own
	items = _merge_publications(items)
	changed.emit()

func _merge_publications(remote: Array) -> Array:
	var merged: Array = remote.filter(func(item: Dictionary) -> bool: return not str(item.get("id","")).begins_with("publication:"))
	var versions: Dictionary = {}
	for item: Dictionary in merged:
		if item.get("kind") == "track_published": versions[str(item.get("version_id",""))] = true
	for item: Dictionary in _publications:
		if not versions.has(str(item.version_id)): merged.append(item)
	merged.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return int(a.get("created_at",0)) > int(b.get("created_at",0)) if a.get("created_at",0) != b.get("created_at",0) else str(a.get("id","")) > str(b.get("id","")))
	return merged.slice(0,100)

func available() -> bool:
	return client.signed_in() and not str(client.player.get("id","")).is_empty() and int(client._capabilities.get("garage_news_version",0)) == 1

func _filter_blocks() -> void:
	var safety: Node = client.get("safety")
	if safety == null: return
	items = items.filter(func(item: Variant) -> bool:
		return item is Dictionary and not safety.is_blocked(str(item.get("actor_id",""))) and not safety.is_blocked(str(item.get("creator_id",""))))
	friends = friends.filter(func(item: Variant) -> bool:
		return item is Dictionary and not safety.is_blocked(str(item.get("player_id",""))))

func blocks_changed() -> void:
	_filter_blocks()
	_fetched_at = -60001
	_friends_at = -60001
	changed.emit()

func refresh(poll: bool = false) -> void:
	identity_changed()
	if busy or not available(): return
	if not poll and Time.get_ticks_msec()-_fetched_at < 60000: return
	busy = true
	error = ""
	changed.emit()
	var epoch: int = _epoch
	var day: int = client.server_now()/86400
	if not poll and checked_day < day:
		var demand: Dictionary = await client.request_api("/news/refresh",HTTPClient.METHOD_POST,{},"",true)
		if epoch != _epoch or scope() != _scope: return
		if not demand.get("ok",false):
			error = _message(str(demand.get("error","")))
			busy = false
			changed.emit()
			return
	var response: Dictionary = await client.request_api("/news",HTTPClient.METHOD_GET,{},"",true)
	if epoch != _epoch or scope() != _scope: return
	busy = false
	if response.get("ok",false):
		var data: Dictionary = response.get("data",{})
		items = _merge_publications(_with_media(data))
		next_cursor = str(data.get("next_cursor",""))
		refreshing = bool(data.get("refreshing",false))
		checked_day = int(data.get("checked_day",-1))
		_fetched_at = Time.get_ticks_msec()
	else:
		error = _message(str(response.get("error","")))
	_filter_blocks()
	changed.emit()

func more() -> void:
	if busy or next_cursor.is_empty() or not available() or items.size() >= 100: return
	busy = true
	changed.emit()
	var epoch: int = _epoch
	var response: Dictionary = await client.request_api("/news?cursor="+next_cursor.uri_encode(),HTTPClient.METHOD_GET,{},"",true)
	if epoch != _epoch or scope() != _scope: return
	busy = false
	if response.get("ok",false):
		var data: Dictionary = response.get("data",{})
		if data.get("items") is Array:
			var known: Dictionary = {}
			for item: Dictionary in items: known[str(item.get("id",""))] = true
			for item: Variant in _with_media(data):
				if item is Dictionary and not known.has(str(item.get("id",""))) and items.size() < 100:
					items.append(item)
					known[str(item.get("id",""))] = true
		next_cursor = str(data.get("next_cursor","")) if items.size() < 100 else ""
		items = _merge_publications(items)
	else: error = _message(str(response.get("error","")))
	_filter_blocks()
	changed.emit()

func load_friends() -> void:
	identity_changed()
	if busy or not available() or Time.get_ticks_msec()-_friends_at < 60000: return
	busy = true
	changed.emit()
	var epoch: int = _epoch
	var response: Dictionary = await client.request_api("/news/friends",HTTPClient.METHOD_GET,{},"",true)
	if epoch != _epoch or scope() != _scope: return
	busy = false
	if response.get("ok",false):
		friends = response.data.get("items",[]) if response.data.get("items") is Array else []
		_friends_at = Time.get_ticks_msec()
	else: error = _message(str(response.get("error","")))
	_filter_blocks()
	changed.emit()

func friend_action(action: String, target: String) -> void:
	if busy or not available(): return
	busy = true
	error = ""
	changed.emit()
	var epoch: int = _epoch
	var path: String = "/news/friends" if action == "send" else "/news/friends/"+target.uri_encode()
	var method: HTTPClient.Method = HTTPClient.METHOD_POST if action == "send" else HTTPClient.METHOD_PUT if action == "accept" else HTTPClient.METHOD_DELETE
	var response: Dictionary = await client.request_api(path,method,{"name":target} if action == "send" else {},"",true)
	if epoch != _epoch or scope() != _scope: return
	busy = false
	if not response.get("ok",false):
		error = _message(str(response.get("error","")))
		changed.emit()
		return
	if action == "remove":
		items = items.filter(func(item: Variant) -> bool:
			return not (item is Dictionary and item.get("kind","") == "friend_track" and str(item.get("actor_id","")) == target))
	_fetched_at = -60001
	_friends_at = -60001
	await load_friends()

static func _message(value: String) -> String:
	match value:
		"PLAYER_NOT_FOUND": return "Player not found. Check the exact racing name."
		"CANNOT_FRIEND_SELF": return "Choose another player."
		"FRIEND_LIMIT_REACHED": return "The friend list is full. Remove a friend or pending request."
		"FRIEND_REQUEST_NOT_FOUND": return "This friend request is no longer available."
	return "News could not be updated. Try again."

static func _with_media(data: Dictionary) -> Array:
	var result: Array = []
	var tracks: Dictionary = data.get("tracks",{}) if data.get("tracks") is Dictionary else {}
	if not data.get("items") is Array: return result
	for value: Variant in data.items.slice(0,30):
		if not value is Dictionary: continue
		var item: Dictionary = value.duplicate()
		var track: Variant = tracks.get(str(item.get("version_id","")),{})
		item["track_points"] = track.get("points",[]) if track is Dictionary else []
		result.append(item)
	return result
