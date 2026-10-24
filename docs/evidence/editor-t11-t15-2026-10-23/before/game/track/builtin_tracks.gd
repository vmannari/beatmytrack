class_name BuiltinTracks
extends RefCounted
## Native catalog, loaded outside the canonical simulation. No legacy reader.

static var _entries: Array[Dictionary] = []

static func entries() -> Array[Dictionary]:
	if _entries.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://resources/builtin_tracks.json"))
		_entries.assign(manifest.entries)
	return _entries

static func ids() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in entries(): result.append(entry.id)
	return result

static func metadata(id: String) -> Dictionary:
	for entry: Dictionary in entries():
		if entry.id == id: return entry
	return {}
