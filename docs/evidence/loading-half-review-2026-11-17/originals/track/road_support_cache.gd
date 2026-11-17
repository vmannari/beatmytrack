extends RefCounted
## Pure numeric support data: no track owners, rendering dependencies or disk I/O.
const MAX_ENTRIES: int = 4
const MAX_BYTES: int = 2 * 1024 * 1024
static var entries: Dictionary = {}
static var bytes: int = 0
static var generation: int = 0
static var guard := Mutex.new()

static func read(key: String) -> Dictionary:
	guard.lock()
	var entry: Dictionary = entries.get(key,{})
	if not entry.is_empty():
		entries.erase(key)
		entries[key] = entry
	var result: Dictionary = {"value":entry.get("value"),"generation":generation}
	guard.unlock()
	return result

static func write(key: String, value: Dictionary, expected_generation: int) -> void:
	# Include headroom for dictionary/array containers beyond serialized numbers.
	var cost: int = var_to_bytes(value).size()*2+key.length()*4+512
	if cost > MAX_BYTES: return
	guard.lock()
	if generation != expected_generation:
		guard.unlock()
		return
	if entries.has(key):
		bytes -= int(entries[key].bytes)
		entries.erase(key)
	while not entries.is_empty() and (entries.size() >= MAX_ENTRIES or bytes+cost > MAX_BYTES):
		var oldest: String = entries.keys()[0]
		bytes -= int(entries[oldest].bytes)
		entries.erase(oldest)
	entries[key] = {"value":value,"bytes":cost}
	bytes += cost
	guard.unlock()

static func trim() -> void:
	guard.lock()
	generation += 1
	entries.clear()
	bytes = 0
	guard.unlock()

static func bytes_used() -> int:
	guard.lock()
	var result: int = bytes
	guard.unlock()
	return result
