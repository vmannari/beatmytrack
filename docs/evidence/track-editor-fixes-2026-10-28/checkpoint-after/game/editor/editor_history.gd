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
			var blocks: Array = []
			var old_blocks: Array = old.get(key,{}).get("blocks",[])
			var reusable: Dictionary = {}
			if prior.size() != document[key].size():
				for chunk: Dictionary in prior: reusable[chunk.value] = chunk
			for start: int in range(0,document[key].size(),64):
				var block_index: int = start/64
				var source: Array = document[key].slice(start,mini(start+64,document[key].size()))
				if block_index < old_blocks.size() and old_blocks[block_index].source == source:
					blocks.append(old_blocks[block_index])
					chunks.append_array(old_blocks[block_index].objects)
					continue
				var members: Array = []
				var frozen: Array = []
				var ids := PackedInt64Array()
				for offset: int in range(source.size()):
					var index: int = start+offset
					var value: Dictionary = source[offset]
					var chunk: Dictionary
					if index < prior.size() and prior[index].value == value: chunk = prior[index]
					else:
						if reusable.is_empty() and ((index+1 < prior.size() and prior[index+1].value == value) or (index>0 and index-1<prior.size() and prior[index-1].value == value)):
							for item: Dictionary in prior: reusable[item.value] = item
						if reusable.has(value): chunk = reusable[value]
						else:
							var snapshot: Dictionary = value.duplicate(true)
							_freeze(snapshot)
							var packed: PackedByteArray = var_to_bytes(snapshot)
							sequence += 1
							chunk = {"id":sequence,"data":packed,"value":snapshot,"bytes":packed.size()*2+512}
					members.append(chunk); frozen.append(chunk.value); ids.append(chunk.id)
				frozen.make_read_only()
				chunks.append_array(members)
				var allocations: Dictionary = {}
				for chunk: Dictionary in members: allocations[chunk.id] = chunk.bytes
				sequence += 1
				blocks.append({"id":sequence,"ids":ids,"objects":members,"source":frozen,"allocations":allocations})
			fields[key] = {"objects":chunks,"blocks":blocks}
			continue
		var data: PackedByteArray = var_to_bytes(document[key])
		if old.has(key) and old[key].data == data: fields[key] = old[key]
		else:
			sequence += 1
			fields[key] = {"id":sequence,"data":data}
	return {"snapshot":fields}

static func _freeze(value: Variant) -> void:
	if value is Dictionary:
		for child: Variant in value.values(): _freeze(child)
		value.make_read_only()
	elif value is Array:
		for child: Variant in value: _freeze(child)
		value.make_read_only()

static func matches(entry: Dictionary, document: Dictionary) -> bool:
	if entry.is_empty() or entry.snapshot.size() != document.size(): return false
	for key: Variant in document:
		if not entry.snapshot.has(key): return false
		var field: Dictionary = entry.snapshot[key]
		if field.has("objects"):
			if field.objects.size() != document[key].size(): return false
			for index: int in range(field.blocks.size()):
				if field.blocks[index].source != document[key].slice(index*64,mini(index*64+64,document[key].size())): return false
		elif field.data != var_to_bytes(document[key]): return false
	return true

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
	var allocations: Dictionary = {}
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
						seen[block.id] = true; total += 128+block.objects.size()*64
						# Native dictionary merging deduplicates shared object chunks
						# without dispatching a script loop for all 4096 each edit.
						allocations.merge(block.allocations,false)
					continue
				if seen.has(chunk.id): continue
				seen[chunk.id] = true
				total += chunk.data.size()+128
	for weight: int in allocations.values(): total += weight
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
