class_name TrackSession
extends RefCounted
## Ordered crossing regions and fixed ticks. Explicit lap count for diagnostics.
## Regions are not falsely reinterpreted as diagonal line segments.

var next_checkpoint: int = 0
var completed_laps: int = 0
var elapsed_ticks: int = 0
var lap_start_time: float = 0.0
var lap_times: Array[float] = []
var finished: bool = false
var tick_rate: int
var target_laps: int
var first_checkpoint_on_finish_approach: bool = false


func _init(rate: int = 120, laps: int = RaceRules.LAPS) -> void:
	tick_rate = rate
	target_laps = laps


func advance(track: NativeTrack, from: Vector2, to: Vector2, route_index: int) -> void:
	if finished:
		return
	elapsed_ticks += 1
	if next_checkpoint == track.checkpoints.size():
		var first: Rect2 = track.checkpoints[0]
		var route_forward: Vector2 = track.route[(route_index + 1) % track.route.size()] - track.route[route_index]
		if not first.has_point(from) and (to - from).dot(route_forward) > 0.0 and entry_fraction(first, from, to) >= 0.0:
			first_checkpoint_on_finish_approach = true
		var before: float = (from - track.finish_center).dot(track.finish_forward)
		var after: float = (to - track.finish_center).dot(track.finish_forward)
		if before <= 0.0 and after > 0.0:
			var crossing: float = -before / (after - before)
			var point: Vector2 = from.lerp(to, crossing) - track.finish_center
			if absf(point.cross(track.finish_forward)) <= track.finish_half_width:
				var time: float = (elapsed_ticks - 1 + crossing) / tick_rate
				lap_times.append(time - lap_start_time)
				lap_start_time = time
				completed_laps += 1
				next_checkpoint = 0
				# Some source finish markings lie inside CP1 (notably 66).
				# Its forward entry occurred on this finish approach after the last CP.
				if first_checkpoint_on_finish_approach and first.has_point(from.lerp(to, crossing)):
					next_checkpoint = 1
				first_checkpoint_on_finish_approach = false
				finished = completed_laps == target_laps
		return
	var gate: Rect2 = track.checkpoints[next_checkpoint]
	# Only entering a region in route direction counts; camping inside cannot count.
	var tangent: Vector2 = track.route[(route_index + 1) % track.route.size()] - track.route[route_index]
	if gate.has_point(from) or (to - from).dot(tangent) <= 0.0:
		return
	var fraction: float = entry_fraction(gate, from, to)
	if fraction < 0.0:
		return
	next_checkpoint += 1


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
