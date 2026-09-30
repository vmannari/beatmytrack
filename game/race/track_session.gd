class_name TrackSession
extends RefCounted
## Ordered swept gates; no route-history/shortcut search per tick.
signal shortcut_detected # Legacy observer API; never emitted by checkpoint rules.
var next_checkpoint: int = 0
var completed_laps: int = 0
var elapsed_ticks: int = 0
var lap_start_time: float = 0.0
var lap_times: Array[float] = []
var finished: bool = false
var tick_rate: int
var target_laps: int
var route_distance: float = 0.0
var finish_armed: bool = false
var initialized: bool = false
var missed_checkpoint: int = -1
# Retained read-model fields; these rules never add time penalties.
var shortcut_count: int = 0
var shortcut_distance: float = 0.0
var penalty_seconds: float = 0.0
var lap_penalty_seconds: float = 0.0
var last_shortcut_tick: int = -1
var last_progress: float = 0.0
var _widths: Array[Vector2] = []
var _road_widths: Array[Vector2] = []
var _centers := PackedVector2Array()
var _directions := PackedVector2Array()
var _progress := PackedFloat32Array()
var _start_progress: float = 0.0

func _init(rate: int = 120, laps: int = RaceRules.LAPS) -> void:
	tick_rate = rate
	target_laps = laps

func _configure(track: NativeTrack) -> void:
	# Bake the gate corridor once. Runtime visits only the current gate and
	# its neighbour, regardless of track length or total gate count.
	_start_progress = track.route_progress(track.finish_center)
	var targets: Array[float] = []
	var count: int = maxi(4,ceili(track.route_length/12.0))
	var corners: Array[Dictionary] = _road_corners(track)
	for i: int in range(1,count):
		var distance: float = track.route_length*i/count
		var overlaps_corner: bool = false
		for corner: Dictionary in corners:
			var separation: float = absf(distance-float(corner.distance))
			separation = minf(separation,track.route_length-separation)
			if separation < float(corner.reach): overlaps_corner = true; break
		if not overlaps_corner: targets.append(distance)
	for corner: Dictionary in corners: targets.append(corner.distance)
	targets.sort()
	var dirt: bool = track.metadata.get("creator_document",{}).get("surface","") == "dirt" or not track.metadata.has("creator_document")
	for distance: float in targets:
		var junction: Dictionary = {}
		for corner: Dictionary in corners:
			if is_equal_approx(distance,float(corner.distance)): junction = corner; break
		if junction.is_empty() and not _progress.is_empty() and distance-_progress[-1] < 3.0: continue
		var absolute: float = _start_progress+distance
		var center: Vector2 = track._race_route_point(absolute)
		var direction: Vector2 = (track._race_route_point(absolute+2.0)-track._race_route_point(absolute-2.0)).normalized()
		if not junction.is_empty():
			center = junction.center
			direction = junction.direction
		var wrapped: float = fposmod(absolute,track.route_length)
		var low: int = 0
		var high: int = track.route.size()-1
		while low < high:
			var mid: int = (low+high+1)/2
			if track.route_cumulative[mid] <= wrapped: low = mid
			else: high = mid-1
		var half: float = maxf(3.0,float(track.metadata.get("representative_width_m",9.0))*0.5)
		if track.route_widths.size() == track.route.size(): half = track.route_widths[low]*0.5
		elif track.route_radii.size() == track.route.size(): half = maxf(3.0,track.route_radii[low]-2.0)
		# A mitred road join is wider along its bisector than either straight.
		if not junction.is_empty(): half = junction.half_span
		var normal: Vector2 = direction.orthogonal()
		var elevated: bool = track.elevated_at(center,low) if track.grid_width > 0 else false
		var widths := Vector2(half+0.75,half+0.75)
		var road_widths := Vector2(half,half)
		var allowed: Array = [0,2,5] if dirt else [0,5]
		if track.grid_width > 0 and track.cell_at(center,elevated) in allowed:
			for side: int in range(2):
				var span: float = 0.0
				var sign_value: float = -1.0 if side == 0 else 1.0
				while span < half+0.75 and track.cell_at(center+normal*span*sign_value,elevated) in allowed: span += 0.25
				widths[side] = minf(half+0.75,span+0.5)
				road_widths[side] = minf(half,span)
		# A shallow excursion already loses grip/time. Allow extra inside
		# recovery space, fading it out before a tight hairpin can be cut.
		var approach: Vector2 = (center-track._race_route_point(absolute-8.0)).normalized()
		var departure: Vector2 = (track._race_route_point(absolute+8.0)-center).normalized()
		var turn: float = absf(approach.angle_to(departure))
		if turn > 0.01:
			var allowance: float = 3.0*(1.0-smoothstep(deg_to_rad(30.0),deg_to_rad(60.0),turn))
			var inside: int = 1 if (departure-approach).dot(normal) > 0.0 else 0
			widths[inside] += allowance
			# Running wide costs distance; keep inside shortcut limits separate.
			widths[1-inside] += 6.0*smoothstep(0.01,0.08,turn)
		_centers.append(center)
		_directions.append(direction)
		_progress.append(distance)
		_widths.append(widths)
		_road_widths.append(road_widths)
	initialized = true

func _road_corners(track: NativeTrack) -> Array[Dictionary]:
	var points: PackedVector2Array = track.route
	var widths: PackedFloat32Array = track.route_widths
	var physical_chain: bool = false
	var pieces: Array = track.metadata.get("creator_document",{}).get("pieces",[])
	if not pieces.is_empty():
		# Automatic route resampling can split an apex into two smaller turns.
		# Use the connected physical road chain to retain the actual joint.
		var chain: Dictionary = RoadPieces.connected_route(pieces)
		if chain.ok:
			points = chain.points
			widths = chain.widths
			physical_chain = true
	var result: Array[Dictionary] = []
	for i: int in range(points.size()):
		var incoming: Vector2 = (points[i]-points[posmod(i-1,points.size())]).normalized()
		var outgoing: Vector2 = (points[(i+1)%points.size()]-points[i]).normalized()
		if incoming.dot(outgoing) >= 0.707: continue
		var direction: Vector2 = (incoming+outgoing).normalized()
		if direction.length_squared() < 0.5: continue
		var progress: float = track.route_progress(points[i]) if physical_chain else track.route_cumulative[i]
		var distance: float = fposmod(progress-_start_progress,track.route_length)
		if distance <= 0.25 or distance >= track.route_length-0.25: continue
		var absolute: float = _start_progress+distance
		var forward: Vector2 = track._race_route_point(absolute+2.0)-track._race_route_point(absolute-2.0)
		var cosine: float = maxf(0.25,direction.dot(incoming))
		if direction.dot(forward) < 0.0: direction = -direction
		var half: float = maxf(3.0,float(track.metadata.get("representative_width_m",9.0))*0.5)
		if widths.size() == points.size(): half = widths[i]*0.5
		elif not physical_chain and track.route_radii.size() == points.size(): half = maxf(3.0,track.route_radii[i]-2.0)
		var half_span: float = half/cosine
		# Keep neighbouring straight gates beyond the inside miter. Otherwise
		# a legal inside line crosses those planes in the opposite order.
		var reach: float = maxf(3.0,(half+0.75)*sqrt(maxf(0.0,1.0-cosine*cosine))/cosine+2.0)
		result.append({"distance":distance,"center":points[i],"direction":direction,"half_span":half_span,"reach":reach})
	return result

func _inside(index: int, point: Vector2) -> bool:
	var lateral: float = (point-_centers[index]).dot(_directions[index].orthogonal())
	return lateral >= -_widths[index].x and lateral <= _widths[index].y

func checkpoint_position(track: NativeTrack) -> Vector2:
	if next_checkpoint >= _centers.size(): return track.finish_center
	# Draw the actual asymmetric span, including the inside recovery margin.
	var widths: Vector2 = _widths[next_checkpoint]
	return _centers[next_checkpoint]+_directions[next_checkpoint].orthogonal()*(widths.y-widths.x)*0.5
func checkpoint_direction(track: NativeTrack) -> Vector2:
	return _directions[next_checkpoint] if next_checkpoint < _directions.size() else track.finish_forward
func checkpoint_width(track: NativeTrack) -> float:
	if next_checkpoint >= _centers.size(): return track.finish_half_width*2.0
	return _widths[next_checkpoint].x+_widths[next_checkpoint].y
func checkpoint_count() -> int: return _centers.size()

func checkpoint_road_center(track: NativeTrack) -> Vector2:
	return _centers[next_checkpoint] if next_checkpoint < _centers.size() else track.finish_center
func checkpoint_road_spans(track: NativeTrack) -> Vector2:
	return _road_widths[next_checkpoint] if next_checkpoint < _road_widths.size() else Vector2.ONE*track.finish_half_width
func checkpoint_acceptance_spans(track: NativeTrack) -> Vector2:
	return _widths[next_checkpoint] if next_checkpoint < _widths.size() else Vector2.ONE*track.finish_half_width

func _crossing(index: int, from: Vector2, to: Vector2) -> float:
	var before: float = (from-_centers[index]).dot(_directions[index])
	var after: float = (to-_centers[index]).dot(_directions[index])
	if before > 0.0 or after <= 0.0: return -1.0
	return -before/(after-before)

func advance(track: NativeTrack, from: Vector2, to: Vector2, route_index: int) -> void:
	if finished: return
	elapsed_ticks += 1
	if track.route_length <= 0.0 or track.route.size() < 2: return
	if not initialized: _configure(track)
	if from.distance_squared_to(to) <= 0.00000001: return
	# A long sweep may cross multiple gates, but only in increasing time order.
	var consumed: float = -1.0
	while next_checkpoint < _centers.size():
		var fraction: float = _crossing(next_checkpoint,from,to)
		if fraction < 0.0 or fraction < consumed-0.000001: break
		var point: Vector2 = from.lerp(to,fraction)
		if not _inside(next_checkpoint,point):
			if point.distance_squared_to(_centers[next_checkpoint]) < 1600.0: missed_checkpoint = next_checkpoint
			break
		consumed = fraction
		next_checkpoint += 1
		missed_checkpoint = -1
	if next_checkpoint+1 < _centers.size():
		var later: float = _crossing(next_checkpoint+1,from,to)
		if later >= 0.0 and _inside(next_checkpoint+1,from.lerp(to,later)): missed_checkpoint = next_checkpoint
	_update_display_progress(track,to,route_index)
	# Crossing the start and the first dense gate in the same fast tick is
	# departure, not an incomplete lap. Arm only after meaningful progress.
	if route_distance >= minf(15.0,track.route_length*0.25): finish_armed = true
	var before: float = (from-track.finish_center).dot(track.finish_forward)
	var after: float = (to-track.finish_center).dot(track.finish_forward)
	if not finish_armed or before > 0.0 or after <= 0.0: return
	var crossing: float = -before/(after-before)
	if absf((from.lerp(to,crossing)-track.finish_center).cross(track.finish_forward)) > track.finish_half_width+1.5: return
	if next_checkpoint < _centers.size():
		missed_checkpoint = next_checkpoint
		return
	if crossing < consumed-0.000001: return
	var time: float = (elapsed_ticks-1+crossing)/tick_rate
	lap_times.append(time-lap_start_time)
	lap_start_time = time
	completed_laps += 1
	finished = completed_laps >= target_laps
	route_distance = 0.0
	next_checkpoint = 0
	finish_armed = false
	missed_checkpoint = -1

func _update_display_progress(track: NativeTrack, point: Vector2, hint: int) -> void:
	# Telemetry only. Reuse the simulation hint and inspect three segments.
	var best: float = INF
	var progress: float = last_progress
	for offset: int in range(-1,2):
		var i: int = posmod(hint+offset,track.route.size())
		var edge: Vector2 = track.route[(i+1)%track.route.size()]-track.route[i]
		var t: float = clampf((point-track.route[i]).dot(edge)/maxf(edge.length_squared(),0.000001),0.0,1.0)
		var distance: float = point.distance_squared_to(track.route[i]+edge*t)
		if distance < best:
			best = distance
			progress = track.route_cumulative[i]+edge.length()*t
	last_progress = progress
	var low: float = _progress[next_checkpoint-1] if next_checkpoint > 0 else 0.0
	var high: float = _progress[next_checkpoint] if next_checkpoint < _progress.size() else track.route_length
	route_distance = clampf(fposmod(progress-_start_progress,track.route_length),low,high)

func shortcut_notice_active() -> bool: return false
func race_time_seconds() -> float:
	return lap_start_time if finished else float(elapsed_ticks)/tick_rate

static func entry_fraction(rect: Rect2, from: Vector2, to: Vector2) -> float:
	var lo: float = 0.0
	var hi: float = 1.0
	var motion: Vector2 = to-from
	for axis: int in range(2):
		if absf(motion[axis]) < 0.000001:
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]: return -1.0
		else:
			var a: float = (rect.position[axis]-from[axis])/motion[axis]
			var b: float = (rect.end[axis]-from[axis])/motion[axis]
			lo = maxf(lo,minf(a,b))
			hi = minf(hi,maxf(a,b))
	return lo if lo <= hi else -1.0
