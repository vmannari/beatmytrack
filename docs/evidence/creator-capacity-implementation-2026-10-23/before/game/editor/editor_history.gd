extends RefCounted
## Immutable binary fields share unchanged authoring data across both stacks.
## This is session history only; saved/published document formats stay unchanged.
const BUDGET: int = 8 * 1024 * 1024
const LIMIT: int = 40
static var sequence: int = 0

static func capture(document: Dictionary, previous: Dictionary = {}) -> Dictionary:
	var fields: Dictionary = {}
	var old: Dictionary = previous.get("snapshot",{})
	for key: Variant in document:
		var data: PackedByteArray = var_to_bytes(document[key])
		if old.has(key) and old[key].data == data: fields[key] = old[key]
		else:
			sequence += 1
			fields[key] = {"id":sequence,"data":data}
	return {"snapshot":fields}

static func restore(entry: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in entry.snapshot: result[key] = bytes_to_var(entry.snapshot[key].data)
	return result

static func bytes_used(stacks: Array) -> int:
	var seen: Dictionary = {}
	var total: int = 0
	for stack: Array in stacks:
		for entry: Dictionary in stack:
			total += 128 + entry.snapshot.size()*64
			for chunk: Dictionary in entry.snapshot.values():
				if seen.has(chunk.id): continue
				seen[chunk.id] = true
				total += chunk.data.size()+128
	return total

static func trim(history: Array, redo: Array, allowance: int = BUDGET) -> void:
	while history.size()+redo.size() > LIMIT:
		if not history.is_empty(): history.pop_front()
		else: redo.pop_front()
	while bytes_used([history,redo]) > allowance:
		# Never retain an over-budget checkpoint, including a single large one.
		if not history.is_empty(): history.pop_front()
		elif not redo.is_empty(): redo.pop_front()
		else: break
