extends RefCounted
## Resolve current access/target before reusing immutable recording bytes.
const CACHE = preload("res://backend/recording_cache.gd")
static var _pending: Dictionary = {}

static func fetch(client: Node, path: String, authorized: bool, expected_run_id: String = "") -> Dictionary:
	var scope: String = client.base_url()+"/"+str(client.player.get("id",""))
	var generation: int = int(client.get("_session_generation"))
	var key: String = str(client.get_instance_id())+"/"+str(generation)+"/"+path+"/"+expected_run_id
	if _pending.has(key):
		var shared: Dictionary = _pending[key]
		while not shared.done:
			await client.get_tree().process_frame
			if generation != int(client.get("_session_generation")): return {}
		return shared.recording.duplicate(true) if _current(client,scope,generation,str(shared.get("owner",""))) else {}
	if _pending.size() >= 16: return {}
	var pending: Dictionary = {"done":false,"recording":{},"owner":""}
	_pending[key] = pending
	pending.recording = await _fetch(client,path,authorized,scope,generation,pending,expected_run_id)
	pending.done = true
	_pending.erase(key)
	return pending.recording

static func _current(client: Node, scope: String, generation: int, player_id: String = "") -> bool:
	return generation == int(client.get("_session_generation")) and scope == client.base_url()+"/"+str(client.player.get("id","")) and (not is_instance_valid(client.get("safety")) or not client.safety.is_blocked(player_id))

static func _fetch(client: Node, path: String, authorized: bool, scope: String, generation: int, pending: Dictionary, expected_run_id: String) -> Dictionary:
	var modern: bool = int(client._capabilities.get("ghost_identity_version",0)) == 1
	var suffix: String = "&" if "?" in path else "?"
	var response: Dictionary = await client.request_api(path+suffix+"metadata=true" if modern else path,HTTPClient.METHOD_GET,{},"",authorized)
	if not response.get("ok",false) or not _current(client,scope,generation): return {}
	if not modern:
		if not expected_run_id.is_empty() and str(response.data.get("run_id","")) != expected_run_id: return {}
		pending.owner = str(response.data.get("player_id",""))
		return CACHE.valid(response.data.get("recording")) if _current(client,scope,generation,pending.owner) else {}
	var metadata: Dictionary = response.data
	if not metadata.get("run_id") is String or not metadata.get("content_hash") is String or str(metadata.content_hash).length() != 64 or not str(metadata.content_hash).is_valid_hex_number(): return {}
	if not expected_run_id.is_empty() and str(metadata.run_id) != expected_run_id: return {}
	var owner: String = str(metadata.get("player_id",""))
	pending.owner = owner
	if not _current(client,scope,generation,owner): return {}
	var identity: String = str(metadata.run_id)+"/"+str(metadata.content_hash)
	var directory: String = str(client.get("recording_cache_directory"))
	var cached: Variant = await client._background(CACHE.read.bind(directory,scope,identity))
	if not _current(client,scope,generation,owner): return {}
	if cached is Dictionary and not cached.is_empty():
		client.recording_cache_hits += 1
		return cached
	var encoding: String = "&encoding=packed" if int(client._capabilities.get("ghost_wire_version",0)) == 1 else ""
	response = await client.request_api(path+suffix+"expected_run_id="+str(metadata.run_id).uri_encode()+encoding,HTTPClient.METHOD_GET,{},"",authorized)
	if not response.get("ok",false) or not _current(client,scope,generation,owner) or str(response.data.get("run_id","")) != str(metadata.run_id) or str(response.data.get("content_hash","")) != str(metadata.content_hash): return {}
	var recording: Dictionary = await client._background(preload("res://backend/ghost_wire.gd").decode.bind(response.data.get("recording")))
	if recording.is_empty(): return {}
	client.recording_downloads += 1
	await client._background(CACHE.write.bind(directory,scope,identity,recording))
	return recording if _current(client,scope,generation,owner) else {}
