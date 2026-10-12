extends SceneTree
## Opt-in validation of real public cache documents; no login or network calls.

func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 1:
		push_error("Provide the public cache directory containing index.json.")
		quit(1)
		return
	var cache: String = arguments[0]
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(cache.path_join("index.json")))
	if not index is Dictionary or not index.get("entries") is Array:
		push_error("Invalid catalog.")
		quit(1)
		return
	var cloud = preload("res://backend/cloud_tracks.gd")
	var failures: int = 0
	for metadata: Dictionary in index.entries:
		var entry: Dictionary = metadata.duplicate(true)
		entry.cache_path = cache.path_join(str(entry.content_hash) + ".json")
		var document: Dictionary = cloud.cached_document(entry)
		var track: NativeTrack = TrackCompiler.compile(document) if not document.is_empty() else null
		if metadata.get("state", "") != "published" or track == null or track.route.size() < 3:
			failures += 1
			push_error("Offline document does not validate/compile: " + str(metadata.get("name", "")))
	print("Offline track bundle: %d published tracks, %d failures; hash/schema/route/compilation checked without network" % [index.entries.size(), failures])
	quit(0 if failures == 0 and not index.entries.is_empty() else 1)
