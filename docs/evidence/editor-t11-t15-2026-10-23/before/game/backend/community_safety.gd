extends Node
## Private, account/origin-scoped block and report recovery. No simulation work.
signal changed
var client: Node
var blocked: Dictionary = {}
var pending_blocks: Dictionary = {}
var pending_reports: Dictionary = {}
var cache_scope: String = ""
var refreshing: bool = false
var last_error: String = ""

func scope() -> String:
	return client.base_url()+"/"+str(client.player.get("id",""))

func _path() -> String:
	if client.session_path.is_empty() or client.player.is_empty(): return ""
	return client.session_path.get_base_dir().path_join("community/"+scope().sha256_text()+".json")

func identity_changed() -> void:
	if cache_scope == scope(): return
	cache_scope = scope()
	blocked.clear()
	pending_blocks.clear()
	pending_reports.clear()
	var path: String = _path()
	if not path.is_empty() and FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		if file != null and file.get_length() <= 262144:
			var data: Variant = JSON.parse_string(file.get_as_text())
			if data is Dictionary:
				if data.get("blocked") is Dictionary: blocked = data.blocked
				if data.get("pending_blocks") is Dictionary: pending_blocks = data.pending_blocks
				if data.get("pending_reports") is Dictionary: pending_reports = data.pending_reports
	changed.emit()
	if client.signed_in() and int(client._capabilities.get("community_safety_version",0)) == 1: refresh.call_deferred()

func _save() -> bool:
	var path: String = _path()
	if path.is_empty(): return true # In-memory standalone adapters.
	return preload("res://backend/cloud_tracks.gd")._write_file(path,{"blocked":blocked,"pending_blocks":pending_blocks,"pending_reports":pending_reports})

func is_blocked(id: String) -> bool:
	return not id.is_empty() and blocked.has(id)

func allows(entry: Dictionary) -> bool:
	return not is_blocked(str(entry.get("creator_id",entry.get("cloud_creator_id",""))))

func mask_public(value: Variant, depth: int = 0) -> void:
	if depth >= 32: return
	if value is Array:
		for item: Variant in value: mask_public(item,depth+1)
	elif value is Dictionary:
		if value.get("entry") is Dictionary and not allows(value.entry): value.available = false
		if value.has("creator_id") and not allows(value):
			if value.has("creator"): value.creator = "Blocked player"
			if value.has("name"): value.name = "Blocked track"
			if value.has("points"): value.points = []
		var id: String = str(value.get("player_id",value.get("driver_id",value.get("id",""))))
		if is_blocked(id):
			for key: String in ["name","display_name"]:
				if value.has(key): value[key] = "Blocked player"
			if value.has("country_code"): value.country_code = ""
			if value.has("appearance"): value.erase("appearance")
		for key: Variant in value: mask_public(value[key],depth+1)

func terms() -> Dictionary:
	return await client.request_api("/community/terms",HTTPClient.METHOD_GET,{},"",true)

func set_block(id: String, name_value: String, value: bool) -> Dictionary:
	if not client.signed_in(): return client._failure("SIGN_IN_REQUIRED")
	if id.is_empty() or id == str(client.player.get("id","")): return client._failure("CANNOT_BLOCK_SELF")
	if value and not blocked.has(id) and blocked.size() >= 1000: return client._failure("BLOCK_LIMIT_REACHED")
	var before: Dictionary = blocked.duplicate(true)
	if value: blocked[id] = name_value
	pending_blocks[id] = value
	if not _save():
		blocked = before
		pending_blocks.erase(id)
		return client._failure("Could not save the block. Free storage and retry.")
	changed.emit()
	var original: String = scope()
	var result: Dictionary = await client.request_api("/community/blocks/"+id.uri_encode(),HTTPClient.METHOD_PUT if value else HTTPClient.METHOD_DELETE,{},"",true)
	if scope() != original: return client._failure("ACCOUNT_CHANGED")
	if not pending_blocks.has(id) or bool(pending_blocks[id]) != value: return result
	if result.ok:
		pending_blocks.erase(id)
		if not value: blocked.erase(id)
	elif int(result.status) >= 400 and int(result.status) < 500 and int(result.status) not in [408,429]:
		blocked = before
		pending_blocks.erase(id)
	_save()
	changed.emit()
	return result

func report(body: Dictionary) -> Dictionary:
	if not client.signed_in(): return client._failure("SIGN_IN_REQUIRED")
	var original: String = scope()
	var key: String = JSON.stringify(body).sha256_text()
	if not pending_reports.has(key):
		if pending_reports.size() >= 20: return client._failure("Retry your saved reports before adding more.")
		var saved: Dictionary = body.duplicate(true)
		saved.command_id = preload("res://backend/product_telemetry.gd").uuid()
		pending_reports[key] = saved
		if not _save():
			pending_reports.erase(key)
			return client._failure("Could not save the report. Free storage and retry.")
	var result: Dictionary = await client.request_api("/reports",HTTPClient.METHOD_POST,pending_reports[key],"",true)
	if scope() != original: return client._failure("ACCOUNT_CHANGED")
	if result.ok or (int(result.status) in [400,403,404,409,422]): pending_reports.erase(key)
	_save()
	changed.emit()
	return result

func refresh() -> void:
	if refreshing or not client.signed_in(): return
	refreshing = true
	var original: String = scope()
	for id: String in pending_blocks.keys():
		await set_block(id,str(blocked.get(id,"Player")),bool(pending_blocks[id]))
		if scope() != original:
			refreshing = false
			if client.signed_in() and int(client._capabilities.get("community_safety_version",0)) == 1: refresh.call_deferred()
			return
	for key: String in pending_reports.keys():
		var body: Dictionary = pending_reports[key].duplicate(true)
		body.erase("command_id")
		await report(body)
		if scope() != original:
			refreshing = false
			if client.signed_in() and int(client._capabilities.get("community_safety_version",0)) == 1: refresh.call_deferred()
			return
	var result: Dictionary = await client.request_api("/community/blocks",HTTPClient.METHOD_GET,{},"",true)
	if scope() == original and result.ok:
		var updated: Dictionary = {}
		for item: Dictionary in result.data.items: updated[str(item.player_id)] = str(item.display_name)
		for id: String in pending_blocks:
			if pending_blocks[id]: updated[id] = blocked.get(id,"Player")
		blocked = updated
		_save()
		changed.emit()
	refreshing = false
	if scope() != original and client.signed_in() and int(client._capabilities.get("community_safety_version",0)) == 1: refresh.call_deferred()
