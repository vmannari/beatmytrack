extends RefCounted
## Process-local, bounded snapshots of already validated cloud compilation.
## Callers receive independent mutable tracks; no tickets or race state cached.
const MAX_ENTRIES: int = 5
const MAX_BYTES: int = 32 * 1024 * 1024
static var _entries: Array[Dictionary] = []
static var _mutex := Mutex.new()

static func clear() -> void:
	_mutex.lock()
	_entries.clear()
	_mutex.unlock()

static func restore(key: Array) -> NativeTrack:
	var snapshot: Dictionary = {}
	_mutex.lock()
	for index: int in range(_entries.size()):
		if _entries[index].key != key: continue
		var entry: Dictionary = _entries.pop_at(index)
		_entries.append(entry)
		snapshot = entry.snapshot
		break
	_mutex.unlock()
	if snapshot.is_empty(): return null
	var track := NativeTrack.new()
	_apply(track,snapshot.track)
	_apply(track.kerbs,snapshot.kerbs)
	_apply(track.snow_banks,snapshot.snow)
	return track

static func remember(key: Array, track: NativeTrack) -> void:
	var snapshot: Dictionary = {"track":_capture(track),"kerbs":_capture(track.kerbs),"snow":_capture(track.snow_banks)}
	var bytes: int = var_to_bytes(snapshot).size()
	if bytes > MAX_BYTES: return
	_mutex.lock()
	for index: int in range(_entries.size()-1,-1,-1):
		if _entries[index].key == key: _entries.remove_at(index)
	var total: int = bytes
	for entry: Dictionary in _entries: total += int(entry.bytes)
	while not _entries.is_empty() and (_entries.size() >= MAX_ENTRIES or total > MAX_BYTES):
		total -= int(_entries.pop_front().bytes)
	_entries.append({"key":key.duplicate(true),"snapshot":snapshot,"bytes":bytes})
	_mutex.unlock()

static func _capture(object: RefCounted) -> Dictionary:
	var values: Dictionary = {}
	for property: Dictionary in object.get_property_list():
		if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE): continue
		var value: Variant = object.get(property.name)
		if value is Object: continue
		values[property.name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return values

static func _apply(object: RefCounted, values: Dictionary) -> void:
	for name: String in values:
		var value: Variant = values[name]
		object.set(name,value.duplicate(true) if value is Array or value is Dictionary else value)
