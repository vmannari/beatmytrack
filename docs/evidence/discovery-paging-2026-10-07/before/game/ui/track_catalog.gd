class_name TrackCatalog
extends RefCounted
## Metadata-only index. No cell expansion or geometry compilation while browsing.

var entries: Array[Dictionary] = []
var library: TrackLibrary
var shared_directories: Array[String] = []
var indexed_revision: int = -1
var source_metadata: Dictionary = {}
var _resolved: Dictionary = {}
var _resolved_revision: int = -1

func clear_resolved() -> void:
	_resolved.clear()
	_resolved_revision = -1

func cached_track(entry: Dictionary) -> NativeTrack:
	if _resolved_revision != indexed_revision or indexed_revision != library.revision:
		_resolved.clear()
		_resolved_revision = indexed_revision
	var id: String = str(entry.id)
	var track: NativeTrack = _resolved.get(id)
	if track != null and entry.get("source") == "cloud" and str(track.metadata.get("cloud_version","")) != str(entry.get("version_id","")):
		_resolved.erase(id)
		track = null
	if track != null:
		# Keep recently revisited tracks when browsing beyond the four-slot cache.
		_resolved.erase(id)
		_resolved[id] = track
	return track

func remember_track(entry: Dictionary, track: NativeTrack) -> void:
	cached_track(entry) # Apply the same revision invalidation before writing.
	_resolved.erase(str(entry.id))
	if _resolved.size() >= 4: _resolved.erase(_resolved.keys()[0])
	_resolved[str(entry.id)] = track

func _init(source: TrackLibrary) -> void:
	library = source
	# Optional native collection manifest. Browsing also works with individually
	# supplied native IDs, without depending on a particular content importer.
	var path: String = "res://resources/builtin_tracks.json"
	if FileAccess.file_exists(path):
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for entry: Dictionary in manifest.get("entries",[]): source_metadata[entry.id] = entry

func add_builtin(id: String) -> void:
	var path: String = "res://resources/tracks/" + id + ".json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var author: Dictionary = source_metadata.get(id,{})
	entries.append({"id":id,"name":str(data.get("title",author.get("name",data.get("name",id.replace("_"," ").to_upper())))),"creator":str(author.get("creator",data.get("creator","Unknown creator"))),"creator_kind":str(author.get("creator_kind","source")),
		"theme":str(data.get("theme","pine")),"source":"builtin","points":data.route,"path":path})

func local_ids() -> Array[String]:
	var ids: Dictionary = {}
	var folder := DirAccess.open(library.directory)
	if folder != null:
		for filename: String in folder.get_files():
			var base: String = filename.trim_suffix(".bak").trim_suffix(".tmp")
			if base.ends_with(".json") and TrackDocument.valid_id(base.trim_suffix(".json")):
				ids[base.trim_suffix(".json")] = true
	var result: Array[String] = []
	result.assign(ids.keys())
	result.sort()
	return result

func add_local(id: String) -> void:
	var path: String = library.directory.path_join(id + ".json")
	for candidate: String in [path,path+".bak",path+".tmp"]:
		var file := FileAccess.open(candidate,FileAccess.READ)
		if file == null: continue
		if file.get_length() > TrackDocument.MAX_BYTES: continue
		var data: Variant = JSON.parse_string(file.get_as_text())
		if not data is Dictionary or data.get("id") != id: continue
		var entry: Dictionary = local_metadata(data)
		if entry.is_empty(): continue
		var date_path: String = library.directory.path_join(id+".created")
		if FileAccess.file_exists(date_path): entry["created_at"] = int(FileAccess.get_file_as_string(date_path))
		entries.append(entry)
		return

func add_shared_tracks() -> void:
	var known: Dictionary = {}
	for entry: Dictionary in entries: known[entry.id] = true
	for directory: String in shared_directories:
		var shared := TrackCatalog.new(TrackLibrary.new(directory))
		for id: String in shared.local_ids(): shared.add_local(id)
		for entry: Dictionary in shared.entries:
			if known.has(entry.id): continue
			entry["library_directory"] = directory
			entry["read_only"] = true
			entries.append(entry)
			known[entry.id] = true

static func local_metadata(data: Dictionary) -> Dictionary:
	if data.get("schema") != TrackDocument.SCHEMA: return {}
	if data.get("base_track","") != "" and str(data.base_track) not in BuiltinTracks.ids(): return {}
	if not TrackDocument.valid_id(data.get("id")): return {}
	for field: String in ["name","creator"]:
		var value: Variant = data.get(field,"Unknown creator")
		if not value is String or value.strip_edges().is_empty() or value.length() > 40 or TrackDocument._has_control(value): return {}
	if data.get("theme") not in TrackDocument.THEMES and data.get("theme") != "coast": return {}
	var points: Variant = data.get("points")
	if not points is Array or points.size() < 4 or points.size() > TrackDocument.MAX_POINTS: return {}
	for point: Variant in points:
		if not point is Array or point.size() != 2: return {}
		for value: Variant in point:
			if not TrackDocument._number(value) or absf(float(value)) > TrackDocument.MAX_COORD: return {}
	return {"id":"creator_"+str(data.id),"local_id":str(data.id),"created_at":data.get("created_at",0),"name":str(data.name),
		"creator":str(data.get("creator","Unknown creator")),"theme":TrackTheme.normalized(str(data.theme)),"source":"saved","points":points,"pieces":data.get("pieces",[])}

func query(state: Dictionary, favorites: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var name_query: String = str(state.get("name","")).strip_edges().to_lower()
	var creator_query: String = str(state.get("creator","")).strip_edges().to_lower()
	var favorite_ids: Dictionary = {}
	for id: String in favorites: favorite_ids[id] = true
	for entry: Dictionary in entries:
		if state.get("section","all") == "favorites" and not favorite_ids.has(entry.id): continue
		if state.get("section","all") == "saved":
			if entry.source == "cloud":
				if not entry.get("owned",false): continue
			elif entry.source != "saved" or entry.get("read_only",false): continue
		if state.get("theme","all") != "all" and entry.theme != state.theme: continue
		if not name_query.is_empty() and not str(entry.name).to_lower().contains(name_query): continue
		if not creator_query.is_empty() and not str(entry.creator).to_lower().contains(creator_query): continue
		result.append(entry)
	var by_creator: bool = state.get("sort","name") == "creator"
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		var first: String = (str(a.creator)+"/" if by_creator else "")+str(a.name)
		var second: String = (str(b.creator)+"/" if by_creator else "")+str(b.name)
		var comparison: int = first.naturalnocasecmp_to(second)
		return str(a.id) < str(b.id) if comparison == 0 else comparison < 0)
	return result

func load_entry_document(entry: Dictionary) -> Dictionary:
	if entry.source == "cloud": return preload("res://backend/cloud_tracks.gd").cached_document(entry)
	var source := TrackLibrary.new(str(entry.get("library_directory", library.directory)))
	return source.load_document(entry.local_id)

func resolve(entry: Dictionary) -> NativeTrack:
	if entry.source == "cloud": return preload("res://backend/cloud_tracks.gd").compile_entry(entry)
	if entry.source == "builtin": return NativeTrack.read(entry.path)
	var data: Dictionary = load_entry_document(entry)
	return null if data.is_empty() else TrackCompiler.compile(data)

static func random_entry(matches: Array[Dictionary], current_id: String, rng: RandomNumberGenerator) -> Dictionary:
	if matches.is_empty(): return {}
	var candidates: Array[Dictionary] = matches.filter(func(entry: Dictionary) -> bool: return entry.id != current_id)
	if candidates.is_empty(): candidates = matches
	return candidates[rng.randi_range(0,candidates.size()-1)]
