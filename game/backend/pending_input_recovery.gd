extends RefCounted
## Bounded recovery of durable input-only uploads; ordinary races use trajectories.
const MAX_FRAMES: int = 216000

static func replay(recording: Dictionary) -> Dictionary:
	if recording.has("race_proof") or not recording.get("frames") is Array: return {}
	var source: Array = recording.frames
	if source.is_empty() or source.size() > MAX_FRAMES: return {}
	var frames: Array = []
	for index: int in range(source.size()):
		var row: Variant = source[index]
		if not row is Array or row.size() not in [3,4,5]: return {}
		if not _whole(row[0],-127,127) or not _whole(row[1],0,255) or not _whole(row[2],0,255): return {}
		if row.size() >= 4 and not _whole(row[3],0,255): return {}
		if row.size() == 5 and (index != 0 or not _whole(row[4],1,2)): return {}
		var frame: Array[int] = []
		for value: Variant in row: frame.append(int(value))
		frames.append(frame)
	var rewinds: Variant = recording.get("rewinds",[])
	if not rewinds is Array or rewinds.size() > 3: return {}
	var events: Array = []
	var receipts: Dictionary = {}
	var offset: int = 0
	var tick: int = 0
	for event: Variant in rewinds:
		if not event is Dictionary or event.size() != 4 or not event.get("receipt_id") is String: return {}
		if event.receipt_id.length() != 36 or receipts.has(event.receipt_id): return {}
		for field: String in ["input_offset","from_tick","to_tick"]:
			if not _whole(event.get(field),0,MAX_FRAMES): return {}
		if not (offset < int(event.input_offset) and int(event.input_offset) < frames.size()): return {}
		if int(event.from_tick) != tick+int(event.input_offset)-offset: return {}
		if int(event.from_tick)-int(event.to_tick) < 1 or int(event.from_tick)-int(event.to_tick) > 1200: return {}
		events.append({"receipt_id":event.receipt_id,"input_offset":int(event.input_offset),"from_tick":int(event.from_tick),"to_tick":int(event.to_tick)})
		receipts[event.receipt_id] = true
		offset = int(event.input_offset)
		tick = int(event.to_tick)
	var result: Dictionary = {"schema":"bmt-replay-v1","frames":frames}
	if not events.is_empty():
		result.schema = "bmt-replay-v2"
		result.rewinds = events
	return result

static func _whole(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high
