extends RefCounted
## Install-time copies are usable only for the server's exact current content hash.
const ROOT: String = "res://resources/cloud_tracks"
static var _index: Dictionary = {}
static var _loaded: bool = false
static var _mutex := Mutex.new()

static func path(content_hash: String) -> String:
	if content_hash.length() != 64 or not content_hash.is_valid_hex_number(): return ""
	_mutex.lock()
	if not _loaded:
		_loaded = true
		var file := FileAccess.open(ROOT.path_join("index.json"),FileAccess.READ)
		if file != null and file.get_length() <= 65536:
			var value: Variant = JSON.parse_string(file.get_as_text())
			if value is Dictionary and value.get("schema") == "bmt-bundled-tracks-v1" and value.get("documents") is Dictionary: _index = value.documents
	var filename: String = content_hash+".json"
	var result: String = ROOT.path_join(filename) if _index.get(content_hash) == filename else ""
	_mutex.unlock()
	return result
