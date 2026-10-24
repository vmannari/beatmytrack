extends RefCounted
## One validated compact encoding per immutable authoring value, shared by WIP/original.
const BUDGET: int = 4 * 1024 * 1024
static var entries: Dictionary = {}
static var bytes: int = 0
static var guard := Mutex.new()

static func prepared(document: Dictionary) -> Dictionary:
	var buffer: PackedByteArray = var_to_bytes(document)
	var digest := HashingContext.new(); digest.start(HashingContext.HASH_SHA256); digest.update(buffer)
	var key: String = digest.finish().hex_encode()
	guard.lock()
	var hit: Dictionary = entries.get(key,{})
	if not hit.is_empty():
		entries.erase(key); entries[key] = hit
		guard.unlock(); return hit
	guard.unlock()
	var content: String = JSON.stringify(document,"",true)
	var result: Dictionary = {"content":content,"fingerprint":content.sha256_text(),"errors":TrackDocument.validate(document,false),"bytes":content.to_utf8_buffer().size()+buffer.size()+256}
	guard.lock()
	if not entries.has(key) and int(result.bytes) <= BUDGET:
		while not entries.is_empty() and bytes+int(result.bytes) > BUDGET:
			var expired: String = entries.keys()[0]; bytes -= int(entries[expired].bytes); entries.erase(expired)
		entries[key] = result; bytes += int(result.bytes)
	guard.unlock()
	return result
