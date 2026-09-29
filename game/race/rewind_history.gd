class_name RewindHistory
extends RefCounted
## 10 Hz state checkpoints; bounded history, independent of render rate.
const WINDOW_TICKS: int = 20 * VehicleSimulation.TICK_RATE
const STRIDE: int = 12
const MAX_RESUMES: int = 3
var entries: Array[Dictionary] = []

static func properties(value: Object, exclude_private: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for property: Dictionary in value.get_property_list():
		var key: String = property.name
		if not (int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE) or (exclude_private and key.begins_with("_")): continue
		var item: Variant = value.get(key)
		result[key] = item.duplicate(true) if item is Array or item is Dictionary else item
	return result

static func restore(value: Object, data: Dictionary) -> void:
	for key: String in data:
		var item: Variant = data[key]
		value.set(key,item.duplicate(true) if item is Array or item is Dictionary else item)

func capture(state: VehicleState, session: TrackSession, force: bool = false, telemetry: LapTelemetry = null) -> void:
	if not force and state.tick % STRIDE != 0: return
	if not entries.is_empty() and int(entries[-1].tick) == state.tick: return
	entries.append({"tick":state.tick,"state":properties(state),"session":properties(session,true)})
	if telemetry != null:
		# Sample/event dictionaries are immutable. Copy their lists, not every point.
		entries[-1].telemetry = {"completed":telemetry.completed.duplicate(),"samples":telemetry.samples.duplicate(),"events":telemetry.events.duplicate(),"stride":telemetry.stride,"lap_start":telemetry.lap_start,"was_off_track":telemetry.was_off_track,"collision_count":telemetry.collision_count,"last_collision_tick":telemetry.last_collision_tick}
	while not entries.is_empty() and int(entries[0].tick) < state.tick-WINDOW_TICKS: entries.pop_front()

func choices(now_tick: int) -> Array[Dictionary]:
	return entries.filter(func(item: Dictionary) -> bool: return int(item.tick) >= now_tick-WINDOW_TICKS and int(item.tick) < now_tick)

func branch(tick: int) -> void:
	entries = entries.filter(func(item: Dictionary) -> bool: return int(item.tick) <= tick)
