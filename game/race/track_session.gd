class_name TrackSession
extends RefCounted
signal shortcut_detected
## Swept route progress, actual driven-path evidence and fixed-tick feedback.
## The route is authoritative; no hand-placed waypoint/checkpoint list is needed.

var next_checkpoint: int = 0
var completed_laps: int = 0
var elapsed_ticks: int = 0
var lap_start_time: float = 0.0
var lap_times: Array[float] = []
var finished: bool = false
var tick_rate: int
var target_laps: int
var route_distance: float = 0.0
var shortcut_count: int = 0
var shortcut_distance: float = 0.0
var penalty_seconds: float = 0.0
var finish_armed: bool = false
var initialized: bool = false
var last_progress: float = 0.0
var shortcut_latched: bool = false
var clean_ticks: int = 0
var clean_distance: float = 0.0
var last_shortcut_tick: int = -1
var lap_penalty_seconds: float = 0.0
var recent_motion := PackedVector2Array()
var bypass_origin: float = 0.0
var bypass_progress: float = 0.0
var bypass_travel: float = 0.0
var bypass_path := PackedVector2Array()


func _init(rate: int = 120, laps: int = RaceRules.LAPS) -> void:
	tick_rate = rate
	target_laps = laps


func advance(track: NativeTrack, from: Vector2, to: Vector2, _route_index: int) -> void:
	if finished: return
	elapsed_ticks += 1
	if track.route_length <= 0.0: return
	if not initialized:
		last_progress = float(track.project_race_route(from).progress)
		recent_motion.append(from)
		bypass_origin = last_progress
		bypass_path.append(from)
		initialized = true
	var motion: Vector2 = to - from
	if motion.length_squared() <= 0.00000001: return
	var steps: int = maxi(1, ceili(motion.length() / 0.5))
	var on_corridor: bool = false
	for step: int in range(steps):
		on_corridor = _follow_motion(track, from.lerp(to, float(step) / steps), from.lerp(to, float(step + 1) / steps))
	if shortcut_latched and last_shortcut_tick != elapsed_ticks:
		clean_ticks = clean_ticks + 1 if on_corridor else 0
		clean_distance = clean_distance + motion.length() if on_corridor else 0.0
		if clean_ticks >= ceili(tick_rate * 0.5) and clean_distance >= 20.0: shortcut_latched = false
	next_checkpoint = clampi(int(maxf(route_distance, 0.0) / track.route_length * track.checkpoints.size()), 0, track.checkpoints.size())
	if to.distance_to(track.finish_center) > minf(maxf(15.0, track.finish_half_width * 2.0), track.route_length * 0.15):
		finish_armed = true
	var before: float = (from - track.finish_center).dot(track.finish_forward)
	var after: float = (to - track.finish_center).dot(track.finish_forward)
	if not finish_armed or before > 0.0 or after <= 0.0 or route_distance < track.route_length * 0.75: return
	var crossing: float = -before / (after - before)
	if absf((from.lerp(to, crossing) - track.finish_center).cross(track.finish_forward)) > track.finish_half_width + 2.0: return
	var time: float = (elapsed_ticks - 1 + crossing) / tick_rate
	# A time penalty is the consequence; do not also discard a driven lap.
	# shortcut_count still excludes the whole attempt from local records.
	lap_times.append(time - lap_start_time + lap_penalty_seconds)
	lap_start_time = time
	lap_penalty_seconds = 0.0
	completed_laps += 1
	finished = completed_laps == target_laps
	route_distance = 0.0
	next_checkpoint = 0
	finish_armed = false
	recent_motion = PackedVector2Array([to])
	bypass_path = PackedVector2Array([to])
	bypass_origin = last_progress
	bypass_progress = 0.0
	bypass_travel = 0.0


func _follow_motion(track: NativeTrack, from: Vector2, to: Vector2) -> bool:
	var motion: Vector2 = to - from
	var observation: Dictionary = track.project_race_route(to, last_progress, motion)
	var delta: float = observation.delta
	var travelled: float = motion.length()
	var radius: float = track.route_radii[int(observation.index)]
	if recent_motion[-1].distance_to(to) >= 0.5:
		recent_motion.append(to)
		if recent_motion.size() > 512: recent_motion.remove_at(0)
	# Compare one contiguous excursion, not the side of the road at its rejoin.
	bypass_progress += delta
	bypass_travel += travelled
	var bypass_driven: PackedVector2Array = recent_motion.duplicate()
	bypass_driven.append(to)
	var gained: float = bypass_progress - bypass_travel
	var cut: bool = track.crosses_hairpin_infield(from,to) or (gained > 8.0 and track.has_cut_gap(bypass_origin, bypass_progress, bypass_driven))
	if cut and not shortcut_latched:
		shortcut_count += 1
		penalty_seconds += 5.0
		lap_penalty_seconds += 5.0
		shortcut_distance += maxf(gained,0.0)
		last_shortcut_tick = elapsed_ticks
		shortcut_latched = true
		shortcut_detected.emit()
		clean_ticks = 0
		clean_distance = 0.0
	# Keep the origin while away from the allowed corridor. Once back on it,
	# retain a short approach so branch changes on adjacent roads are covered.
	if bypass_path[-1].distance_to(to) >= 0.5: bypass_path.append(to)
	if (float(observation.distance) <= radius and bypass_travel > 40.0 and absf(delta) < travelled * 2.0) or bypass_path.size() > 256 or cut:
		bypass_origin = observation.progress
		bypass_progress = 0.0
		bypass_travel = 0.0
		bypass_path = PackedVector2Array([to])
	# Signed distance, never positive-only accumulation: reverse/forward
	# rocking cannot manufacture a completed lap.
	route_distance += delta
	last_progress = observation.progress
	var route_edge: Vector2 = track.route[(int(observation.index) + 1) % track.route.size()] - track.route[int(observation.index)]
	return float(observation.distance) <= radius * 0.75 and motion.normalized().dot(route_edge.normalized()) >= 0.9


func shortcut_notice_active() -> bool:
	return last_shortcut_tick >= 0 and elapsed_ticks - last_shortcut_tick < tick_rate * 2


func race_time_seconds() -> float:
	return (lap_start_time if finished else float(elapsed_ticks) / float(tick_rate)) + penalty_seconds


static func entry_fraction(rect: Rect2, from: Vector2, to: Vector2) -> float:
	var lo: float = 0.0
	var hi: float = 1.0
	var motion: Vector2 = to - from
	for axis: int in range(2):
		if absf(motion[axis]) < 0.000001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return -1.0
		else:
			var a: float = (rect.position[axis] - from[axis]) / motion[axis]
			var b: float = (rect.end[axis] - from[axis]) / motion[axis]
			lo = maxf(lo, minf(a, b))
			hi = minf(hi, maxf(a, b))
	return lo if lo <= hi else -1.0
