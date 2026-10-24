class_name RewindHistory
extends RefCounted
## 10 Hz state checkpoints; bounded history, independent of render rate.
const WINDOW_TICKS: int = 10 * VehicleSimulation.TICK_RATE
const STRIDE: int = 12
const MAX_RESUMES: int = 3
var entries: Array[Dictionary] = []
const SNAPSHOT_VERSION: int = 1
const ARRAY_FIELDS: Array[String] = ["loose_tyres","light_props","prop_destruction","prop_fragments"]
const STATE_FIELDS: Array[String] = ["kerb_offset", "kerb_velocity", "bump_transfer", "jump_height", "jump_velocity", "jump_cooldown", "bridge_airborne", "bridge_gravity", "bridge_descending", "bridge_landing_speed", "loose_tyres", "light_props", "prop_destruction", "prop_fragments", "position", "velocity", "heading", "yaw_rate", "steering", "grip", "reverse_wait", "handbrake_pressure", "launch_pending", "launch_result", "launch_end_tick", "launch_delay_until", "launch_gain", "tick", "collision_count", "collision_impulse", "scrape_strength", "scrape_normal", "scrape_speed", "route_index", "track_elevated", "tire_oil", "tire_water", "roll_ticks", "roll_direction", "roll_cooldown", "tire_dirt"]
const SESSION_FIELDS: Array[String] = ["next_checkpoint", "completed_laps", "elapsed_ticks", "lap_start_time", "lap_times", "finished", "tick_rate", "target_laps", "route_distance", "finish_armed", "initialized", "missed_checkpoint", "last_progress"]
var _telemetry_sources: Array = [null,null,null]
var _telemetry_journals: Array = [null,null,null]

static func properties(value: Object, exclude_private: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in value.get_property_list():
		var key: String = property.name
		if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) or (exclude_private and key.begins_with("_")): continue
		var item: Variant = value.get(key)
		result[key] = item.duplicate(true) if item is Array or item is Dictionary else item
	return result

static func restore(value: Object, data: Variant) -> void:
	if data is Dictionary and data.has("_rewind_schema"):
		var unpacked: Variant = bytes_to_var(data.get("_rewind_arrays",PackedByteArray()))
		if int(data._rewind_schema) != SNAPSHOT_VERSION or not unpacked is Array or unpacked.size() != ARRAY_FIELDS.size():
			push_error("Unsupported rewind state snapshot."); return
		for key: String in STATE_FIELDS:
			var index: int = ARRAY_FIELDS.find(key)
			value.set(key,unpacked[index] if index >= 0 else data[key])
		return
	if data is TelemetrySnapshot: data = data.dictionary()
	for key: String in data:
		var item: Variant = data[key]
		value.set(key,item.duplicate(true) if item is Array or item is Dictionary else item)

func capture(state: VehicleState, session: TrackSession, force: bool = false, telemetry: LapTelemetry = null, glass_damage: Vector4 = Vector4.ZERO) -> void:
	if not force and state.tick % STRIDE != 0: return
	if not entries.is_empty() and int(entries[-1].tick) == state.tick: return
	entries.append({"tick":state.tick,"state":pack_state(state),"session":session_snapshot(session),"glass_damage":glass_damage})
	if telemetry != null:
		var lists: Array = [telemetry.completed,telemetry.samples,telemetry.events]
		var counts := PackedInt32Array()
		for index: int in range(3):
			var source: Array = lists[index]
			var journal: Journal = _telemetry_journals[index]
			# Lap completion, decimation and rewind assign a different list. Never
			# mutate a retained prefix; old snapshots keep their previous journal.
			if journal == null or not is_same(source,_telemetry_sources[index]) or source.size()<journal.values.size():
				journal = Journal.new(); _telemetry_journals[index] = journal; _telemetry_sources[index] = source
			for offset: int in range(journal.values.size(),source.size()): journal.values.append(source[offset])
			counts.append(source.size())
		entries[-1].telemetry = TelemetrySnapshot.new(_telemetry_journals,counts,telemetry)

	while not entries.is_empty() and int(entries[0].tick) < state.tick-WINDOW_TICKS: entries.pop_front()

func choices(now_tick: int) -> Array[Dictionary]:
	return entries.filter(func(item: Dictionary) -> bool: return int(item.tick) >= now_tick-WINDOW_TICKS and int(item.tick) < now_tick)

func branch(tick: int) -> void:
	entries = entries.filter(func(item: Dictionary) -> bool: return int(item.tick) <= tick)

static func pack_state(state: VehicleState) -> Dictionary:
	var result: Dictionary = {"_rewind_schema":SNAPSHOT_VERSION}
	var arrays: Array = []
	for key: String in STATE_FIELDS:
		if key not in ARRAY_FIELDS: result[key] = state.get(key)
	for key: String in ARRAY_FIELDS: arrays.append(state.get(key))
	# Keep cheap scalar pose fields available to rewind markers. The engine
	# codec retains exact Variant types/precision for independently owned bodies.
	result._rewind_arrays = var_to_bytes(arrays)
	return result

static func session_snapshot(session: TrackSession) -> Dictionary:
	var result: Dictionary = {}
	for key: String in SESSION_FIELDS:
		var item: Variant = session.get(key)
		result[key] = item.duplicate(true) if item is Array or item is Dictionary else item
	return result

class Journal extends RefCounted:
	var values: Array[Dictionary] = []

class TelemetrySnapshot extends RefCounted:
	var _journals: Array
	var _counts: PackedInt32Array
	var stride: int
	var lap_start: float
	var was_off_track: bool
	var collision_count: int
	var last_collision_tick: int
	var events_truncated: bool
	var completed: Array[Dictionary]:
		get: return _journals[0].values.slice(0,_counts[0])
	var samples: Array[Dictionary]:
		get: return _journals[1].values.slice(0,_counts[1])
	var events: Array[Dictionary]:
		get: return _journals[2].values.slice(0,_counts[2])
	func _init(journals: Array, counts: PackedInt32Array, source: LapTelemetry) -> void:
		_journals = journals.duplicate(); _counts = counts
		stride = source.stride; lap_start = source.lap_start; was_off_track = source.was_off_track
		collision_count = source.collision_count; last_collision_tick = source.last_collision_tick
		events_truncated = source.events_truncated
	func dictionary() -> Dictionary:
		return {"completed":completed,"samples":samples,"events":events,"stride":stride,"lap_start":lap_start,"was_off_track":was_off_track,"collision_count":collision_count,"last_collision_tick":last_collision_tick,"events_truncated":events_truncated}
