extends RefCounted
## Local preview cache. Plain binary snapshots own their mutable contact data.
const BUDGET: int = 16 * 1024 * 1024
const LIMIT: int = 3

static func geometry(document: Dictionary) -> Dictionary:
	var key: Dictionary = document.duplicate(true)
	for field: String in ["id","name","creator"]: key.erase(field)
	return key

static func fields(value: Object) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in value.get_property_list():
		if not int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: continue
		var name: String = property.name
		if name.begins_with("editor_"): continue
		var item: Variant = value.get(name)
		result[name] = fields(item) if item is RoadKerbs else item
	return result

static func restore(document: Dictionary, cache: Dictionary) -> NativeTrack:
	var key: Dictionary = geometry(document)
	var entries: Array = cache.get("prepared",[])
	for index: int in range(entries.size()):
		var entry: Dictionary = entries[index]
		if entry.key != key: continue
		entries.remove_at(index); entries.append(entry)
		var data: Dictionary = bytes_to_var(entry.data)
		var track := NativeTrack.new()
		for name: String in data:
			if name in ["kerbs","snow_banks"]:
				var contact: RoadKerbs = track.get(name)
				for field: String in data[name]: contact.set(field,data[name][field])
			else: track.set(name,data[name])
		track.metadata.creator_document = document.duplicate(true)
		track.metadata.identity = "creator_"+str(document.id)
		track.metadata.name = document.name; track.metadata.title = document.name
		track.identity = track.metadata.identity
		track.content_hash = TrackCompiler.document_hash(document,str(track.metadata.provenance.base_hash))
		cache["prepared_hits"] = int(cache.get("prepared_hits",0))+1
		return track
	return null

static func remember(document: Dictionary, track: NativeTrack, cache: Dictionary) -> void:
	var key: Dictionary = geometry(document)
	var data: PackedByteArray = var_to_bytes(fields(track))
	var size: int = data.size()+var_to_bytes(key).size()+256
	if size > BUDGET: return
	var entries: Array = cache.get("prepared",[])
	var total: int = 0
	for entry: Dictionary in entries: total += int(entry.bytes)
	while not entries.is_empty() and (entries.size() >= LIMIT or total+size > BUDGET): total -= int(entries.pop_front().bytes)
	entries.append({"key":key,"data":data,"bytes":size})
	cache["prepared"] = entries; cache["prepared_bytes"] = total+size

static func trim_auxiliary(cache: Dictionary) -> void:
	var keys: Array[String] = ["key","cells","sections_key","sections","bridges","overlay_key","overlay_image","road_key","road_image"]
	var values: Array = []
	var bytes: int = 0
	for key: String in keys:
		var value: Variant = cache.get(key)
		if value is Image: bytes += value.get_data().size()
		else: values.append(value)
	bytes += var_to_bytes(values).size()
	if bytes > 8*1024*1024:
		for key: String in keys: cache.erase(key)
		bytes = 0
	cache["auxiliary_bytes"] = bytes
