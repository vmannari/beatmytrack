extends RefCounted
## Immutable verified binary documents/summaries. Always verify current file bytes.
const BUDGET: int = 32 * 1024 * 1024
const LIMIT: int = 1024
static var entries: Dictionary = {}
static var bytes: int = 0
static var guard := Mutex.new()

static func get_value(path: String, digest: String, summary: bool = false) -> Dictionary:
	var key: String = ("summary:" if summary else "document:")+path
	guard.lock()
	var entry: Dictionary = entries.get(key,{})
	var buffer: PackedByteArray = entry.data if entry.get("digest","") == digest else PackedByteArray()
	guard.unlock()
	return bytes_to_var(buffer) if not buffer.is_empty() else {}

static func put_value(path: String, digest: String, value: Dictionary, summary: bool = false) -> void:
	var data: PackedByteArray = var_to_bytes(value)
	var key: String = ("summary:" if summary else "document:")+path
	var size: int = data.size()+key.to_utf8_buffer().size()+digest.length()+96
	if size > BUDGET: return
	guard.lock()
	if entries.has(key): bytes -= int(entries[key].bytes); entries.erase(key)
	while not entries.is_empty() and (entries.size() >= LIMIT or bytes+size > BUDGET):
		var expired: String = entries.keys()[0]
		bytes -= int(entries[expired].bytes); entries.erase(expired)
	entries[key] = {"digest":digest,"data":data,"bytes":size}
	bytes += size
	guard.unlock()

static func digest(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256); context.update(data)
	return context.finish().hex_encode()
