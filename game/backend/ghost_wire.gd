extends RefCounted
## Lossless Float64 presentation decoder. Never used by score verification.
const CACHE = preload("res://backend/recording_cache.gd")
const STRIDE: int = 56

static func decode(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	if value.get("schema") != "bmt-packed-ghost-v1": return CACHE.valid(value)
	if not (value.get("count") is int or value.get("count") is float) or float(value.count) != floorf(float(value.count)): return {}
	var count: int = int(value.count)
	if count < 2 or count > 36007 or not value.get("data") is String or value.data.length() > 3*1024*1024: return {}
	var text: String = value.data
	if text.length()%4 != 0 or RegEx.create_from_string("^[A-Za-z0-9+/]*={0,2}$").search(text) == null: return {}
	var compressed: PackedByteArray = Marshalls.base64_to_raw(text)
	var body: PackedByteArray = compressed.decompress_dynamic(36007*STRIDE,FileAccess.COMPRESSION_GZIP)
	if body.size() != count*STRIDE: return {}
	var poses: Array = []
	for index: int in range(count):
		var row: Array = []
		for component: int in range(7): row.append(body.decode_double(index*STRIDE+component*8))
		poses.append(row)
	return CACHE.valid({"ticks":value.get("ticks"),"poses":poses})
