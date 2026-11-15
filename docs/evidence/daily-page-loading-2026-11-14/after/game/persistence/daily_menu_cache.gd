extends RefCounted
## Short-lived presentation only. Starting a race still requires server validation.
const IO = preload("res://backend/atomic_json.gd")
const MAX_BYTES: int = 131072
const MAX_ITEMS: int = 8
const MAX_AGE_SECONDS: int = 300

static func read(records: LocalRecords, scope: String, kind: String) -> Dictionary:
	if records == null: return {}
	var saved: Dictionary = IO.read(records.path+".daily-menu.json",MAX_BYTES)
	if saved.get("schema") != 1 or not saved.get("items") is Array: return {}
	var now: int = int(Time.get_unix_time_from_system())
	for item: Variant in saved.items:
		if not item is Dictionary or item.get("scope") != scope or item.get("kind") != kind: continue
		if not _whole(item.get("sample_unix")) or not item.get("data") is Dictionary: continue
		var elapsed: int = now-int(item.sample_unix)
		var data: Dictionary = item.data
		if elapsed < 0 or elapsed >= MAX_AGE_SECONDS or not _whole(data.get("server_now")) or not _whole(data.get("ends_at")): continue
		var server_now: int = int(data.server_now)+elapsed
		if server_now >= int(data.ends_at): continue
		var result: Dictionary = data.duplicate(true)
		result.server_now = server_now
		result.sample_msec = Time.get_ticks_msec()
		return result
	return {}

static func write(records: LocalRecords, scope: String, kind: String, data: Dictionary) -> void:
	if records == null: return
	var path: String = records.path+".daily-menu.json"
	var saved: Dictionary = IO.read(path,MAX_BYTES)
	var items: Array = saved.get("items",[]) if saved.get("schema") == 1 and saved.get("items") is Array else []
	var now: int = int(Time.get_unix_time_from_system())
	items = items.filter(func(item: Variant) -> bool:
		return item is Dictionary and _whole(item.get("sample_unix")) and int(item.sample_unix) <= now and now-int(item.sample_unix) < MAX_AGE_SECONDS and not (item.get("scope") == scope and item.get("kind") == kind))
	while items.size() >= MAX_ITEMS: items.pop_front()
	items.append({"scope":scope,"kind":kind,"sample_unix":now,"data":data.duplicate(true)})
	IO.write(path,{"schema":1,"items":items},MAX_BYTES)

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))

static func erase(records: LocalRecords, scope: String, kind: String) -> void:
	if records == null: return
	var path: String = records.path+".daily-menu.json"
	var saved: Dictionary = IO.read(path,MAX_BYTES)
	if saved.get("schema") != 1 or not saved.get("items") is Array: return
	var items: Array = saved.items.filter(func(item: Variant) -> bool:
		return item is Dictionary and not (item.get("scope") == scope and item.get("kind") == kind))
	if items.size() != saved.items.size(): IO.write(path,{"schema":1,"items":items},MAX_BYTES)
