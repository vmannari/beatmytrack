extends RefCounted
## One integer per immutable input, outside canonical simulation and wire formats.
const MAX_INPUTS: int = 216000

static func pack(frame: DriveFrame) -> int:
	return (frame.steer & 255) | (frame.throttle << 8) | (frame.brake << 16) | (frame.handbrake << 24) | (frame.launch_start << 32)

static func unpack(value: int, index: int = 0) -> Array[int]:
	if value < 0 or value >> 34 != 0: return []
	var steer: int = value & 255
	if steer > 127: steer -= 256
	var launch: int = value >> 32
	if steer < -127 or launch > 2 or (launch > 0 and index != 0): return []
	var result: Array[int] = [steer,(value >> 8) & 255,(value >> 16) & 255]
	var handbrake: int = (value >> 24) & 255
	if handbrake > 0 or launch > 0: result.append(handbrake)
	if launch > 0: result.append(launch)
	return result

static func legacy(frames: Variant) -> Array:
	if not (frames is Array or frames is PackedInt64Array): return []
	if frames.is_empty() or frames.size() > MAX_INPUTS: return []
	var result: Array = []
	for index: int in range(frames.size()):
		var value: Variant = frames[index]
		if value is int:
			var row: Array[int] = unpack(value,index)
			if row.is_empty(): return []
			result.append(row)
		elif value is Array:
			# Existing diagnostic and pre-update input-only journals remain exact.
			if value.size() < 3 or value.size() > 5: return []
			for channel: int in range(value.size()):
				if not value[channel] is int: return []
				var low: int = -127 if channel == 0 else 1 if channel == 4 else 0
				var high: int = 127 if channel == 0 else 2 if channel == 4 else 255
				if value[channel] < low or value[channel] > high or (channel == 4 and index != 0): return []
			result.append(value)
		else: return []
	return result

static func count(recording: Dictionary) -> int:
	if recording.get("frames") is Array:
		return recording.frames.size() if recording.frames.size() <= MAX_INPUTS else 0
	if recording.get("schema") != "bmt-local-trajectory-v1" or not recording.has("race_proof"): return 0
	var value: Variant = recording.get("input_count")
	if not (value is int or value is float) or not is_finite(float(value)) or float(value) != floorf(float(value)): return 0
	return int(value) if value > 0 and value <= MAX_INPUTS else 0
