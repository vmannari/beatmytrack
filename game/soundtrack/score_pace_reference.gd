class_name ScorePaceReference
extends RefCounted
## Bounded presentation-only distance/time lookup from an existing recorded ghost.
const MAX_POINTS: int = 2048
var distances := PackedFloat32Array()
var times := PackedFloat32Array()
var lap: bool = false


func configure(track: NativeTrack, recording: Dictionary, is_lap: bool = false) -> void:
	distances.clear()
	times.clear()
	lap = is_lap
	if track == null or track.route_length <= 0 or not recording.get("poses") is Array: return
	var poses: Array = recording.poses
	if poses.size() < 2: return
	var origin: float = track.route_progress(track.finish_center)
	var hint: int = -1
	var previous: float = 0.0
	var total: float = 0.0
	var unwrapped: float = 0.0
	var last_point := Vector2.ZERO
	var stride: int = maxi(1, ceili(float(poses.size()) / MAX_POINTS))
	for index: int in range(0, poses.size(), stride):
		var pose: Variant = poses[index]
		if not pose is Array or pose.size() < 3: distances.clear(); times.clear(); return
		var point := Vector2(float(pose[1]), float(pose[2]))
		if not is_finite(point.x) or not is_finite(point.y) or not is_finite(float(pose[0])): distances.clear(); times.clear(); return
		hint = _nearest(track, point, hint, last_point.distance_to(point) if not distances.is_empty() else 0.0)
		last_point = point
		# Sparse/decimated recordings can move beyond the canonical 25-vertex
		# continuity window. Reacquire only when its projected segment is distant.
		var projected: Vector2 = track._race_route_point(track.route_progress(point, hint))
		if projected.distance_to(point) > maxf(6.0, float(track.metadata.get("representative_width_m",9.0))):
			hint = track.nearest_route(point)
		var distance: float = fposmod(track.route_progress(point, hint) - origin, track.route_length)
		if distances.is_empty():
			unwrapped = distance - track.route_length if distance > track.route_length * 0.85 else distance
			total = unwrapped
		else:
			var delta: float = wrapf(distance - previous, -track.route_length * 0.5, track.route_length * 0.5)
			# Ghost stops/backtracking do not create negative or fabricated progress.
			unwrapped += delta
			total = maxf(total, unwrapped)
		previous = distance
		distances.append(maxf(0.0, total))
		times.append(float(pose[0]) / VehicleSimulation.TICK_RATE)


static func _nearest(track: NativeTrack, point: Vector2, previous: int, displacement: float) -> int:
	if previous < 0: return track.nearest_route(point)
	# Pose decimation needs a wider search than the canonical 25-vertex window.
	var spacing: float = track.route_length / maxf(1.0, track.route.size())
	var count: int = mini(track.route.size(), maxi(25, ceili(displacement / maxf(.25, spacing) * 2.5) + 25))
	var best: int = previous
	var best_distance: float = INF
	for offset: int in range(count):
		var index: int = posmod(previous + offset - count / 2, track.route.size())
		var distance: float = track.route[index].distance_squared_to(point)
		if distance < best_distance: best_distance = distance; best = index
	return best


func delta_seconds(distance: float, elapsed: float) -> float:
	if distances.size() < 2 or distance < distances[0] or distance > distances[-1]: return NAN
	var low: int = 0
	var high: int = distances.size() - 1
	while low < high:
		var middle: int = (low + high) / 2
		if distances[middle] < distance: low = middle + 1
		else: high = middle
	if low == 0: return times[0] - elapsed
	var weight: float = clampf((distance - distances[low - 1]) / maxf(0.00001, distances[low] - distances[low - 1]), 0.0, 1.0)
	return lerpf(times[low - 1], times[low], weight) - elapsed
