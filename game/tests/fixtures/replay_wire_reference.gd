extends RefCounted
## Historical input codec for offline replay regression only.
static func pack(frames: Array, rewinds: Array, compact: bool = true, race_proof: Dictionary = {}, include_incidents: bool = false) -> Dictionary:
	# Godot's JSON parser returns floats, including integers restored from the outbox.
	# Preserve the strict wire schema without accepting fractional/corrupt controls.
	var packed: Array = []
	for frame: Variant in frames:
		if not frame is Array or frame.size() not in [3, 4, 5]: return {}
		var values: Array[int] = []
		for value: Variant in frame:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) != float(int(value)): return {}
			values.append(int(value))
		packed.append(values)
	var replay: Dictionary = {"schema":"bmt-replay-v1","frames":packed}
	if not race_proof.is_empty():
		if race_proof.get("schema","") != "bmt-race-proof-v1" or not race_proof.get("samples") is Array: return {}
		var samples: Array = []
		for row: Variant in race_proof.samples:
			if not row is Array or row.size() != 8: return {}
			for value: Variant in row:
				if not (value is int or value is float) or not is_finite(float(value)): return {}
			if float(row[0]) != float(int(row[0])) or float(row[6]) != float(int(row[6])): return {}
			var sample: Array = row.duplicate()
			sample[0] = int(row[0]); sample[6] = int(row[6])
			samples.append(sample)
		replay.race_proof = {"schema":"bmt-race-proof-v1","samples":samples}
		var incidents: Variant = race_proof.get("incidents")
		if include_incidents and incidents is Dictionary and incidents.size() == 4 and incidents.get("schema") == "bmt-race-incidents-v1" and _whole(incidents.get("ticks"),1,216000) and _whole(incidents.get("collision_count"),0,216000) and incidents.get("off_track") is bool:
			replay.race_proof.incidents = {"schema":"bmt-race-incidents-v1","ticks":int(incidents.ticks),"collision_count":int(incidents.collision_count),"off_track":incidents.off_track}
	if not rewinds.is_empty():
		replay.schema = "bmt-replay-v2"
		replay.rewinds = []
		for source: Dictionary in rewinds:
			var event: Dictionary = {"receipt_id":str(source.get("receipt_id",""))}
			for field: String in ["input_offset","from_tick","to_tick"]:
				var value: Variant = source.get(field)
				if not (value is int or value is float) or not is_finite(float(value)) or float(value) != float(int(value)): return {}
				event[field] = int(value)
			replay.rewinds.append(event)

	var controls := PackedByteArray()
	controls.resize(packed.size()*6)
	for index: int in range(packed.size()):
		var frame: Array = packed[index]
		if frame[0] < -127 or frame[0] > 127 or frame[1] < 0 or frame[1] > 255 or frame[2] < 0 or frame[2] > 255 or (frame.size() >= 4 and (frame[3] < 0 or frame[3] > 255)) or (frame.size() == 5 and (index != 0 or frame[4] not in [1,2])): return {}
		controls[index*6] = frame.size()
		controls[index*6+1] = int(frame[0])+127
		controls[index*6+2] = int(frame[1])
		controls[index*6+3] = int(frame[2])
		controls[index*6+4] = int(frame[3]) if frame.size() >= 4 else 0
		controls[index*6+5] = int(frame[4]) if frame.size() == 5 else 0
	if not compact: return replay
	var wire: Dictionary = {"schema":"bmt-packed-input-v1","replay_schema":replay.schema,"frame_count":packed.size(),"controls":Marshalls.raw_to_base64(controls)}
	if replay.has("rewinds"): wire.rewinds = replay.rewinds
	if replay.has("race_proof"): wire.race_proof = replay.race_proof
	return wire


static func _whole(value: Variant, minimum: int = 0, maximum: int = 9007199254740991) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and float(value) == float(int(value))
