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
		if key == "objects" and document[key] is Array:
			var chunks: Array = []
			var prior: Array = old.get(key,{}).get("objects",[])
			var reusable: Dictionary = {}
			if prior.size() != document[key].size():
				for chunk: Dictionary in prior: reusable[chunk.data] = chunk
			for index: int in range(document[key].size()):
				var packed: PackedByteArray = var_to_bytes(document[key][index])
				if index < prior.size() and prior[index].data == packed: chunks.append(prior[index])
				else:
					if reusable.is_empty() and ((index+1 < prior.size() and prior[index+1].data == packed) or (index>0 and index-1<prior.size() and prior[index-1].data == packed)):
						for chunk: Dictionary in prior: reusable[chunk.data] = chunk
					if reusable.has(packed): chunks.append(reusable[packed])
					else: sequence += 1; chunks.append({"id":sequence,"data":packed})
			var blocks: Array = []
			var old_blocks: Array = old.get(key,{}).get("blocks",[])
			for start: int in range(0,chunks.size(),64):
				var members: Array = chunks.slice(start,mini(start+64,chunks.size()))
				var ids := PackedInt64Array()
				for chunk: Dictionary in members: ids.append(chunk.id)
				var index: int = start/64
				if index < old_blocks.size() and old_blocks[index].ids == ids: blocks.append(old_blocks[index])
				else: sequence += 1; blocks.append({"id":sequence,"ids":ids,"objects":members})
			fields[key] = {"objects":chunks,"blocks":blocks}
			continue
		var data: PackedByteArray = var_to_bytes(document[key])
		if old.has(key) and old[key].data == data: fields[key] = old[key]
		else:
			sequence += 1
			fields[key] = {"id":sequence,"data":data}
	return {"snapshot":fields}

static func restore(entry: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in entry.snapshot:
		if entry.snapshot[key].has("objects"):
			var objects: Array = []
			for chunk: Dictionary in entry.snapshot[key].objects: objects.append(bytes_to_var(chunk.data))
			result[key] = objects
		else: result[key] = bytes_to_var(entry.snapshot[key].data)
	return result

static func bytes_used(stacks: Array) -> int:
	var seen: Dictionary = {}
	var total: int = 0
	for stack: Array in stacks:
		for entry: Dictionary in stack:
			total += 128 + entry.snapshot.size()*64
			for chunk: Dictionary in entry.snapshot.values():
				if chunk.has("objects"):
					total += 64+chunk.objects.size()*8
					total += chunk.blocks.size()*8
					for block: Dictionary in chunk.blocks:
						if seen.has(block.id): continue
						seen[block.id] = true; total += 128+block.objects.size()*16
						for object: Dictionary in block.objects:
							if seen.has(object.id): continue
							seen[object.id] = true; total += object.data.size()+128
					continue
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
