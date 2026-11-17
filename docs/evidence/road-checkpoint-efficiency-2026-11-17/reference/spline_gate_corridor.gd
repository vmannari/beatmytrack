class_name SplineGateCorridor
extends RefCounted
## Preserve ordinary recovery while keeping folded hairpin apices mandatory.
const LANE_HALF_STEPS: int = 28
const LANE_COUNT: int = LANE_HALF_STEPS*2+1
const EDGE_HALF_STEPS: int = 22
const ROAD_EDGE_MARGIN_M: float = 0.5
const APEX_SLACK_M: float = 0.5
const HAIRPIN_MITER_RATIO: float = 1.8

static func _lane_basis(track: NativeTrack) -> Dictionary:
	var normals := PackedVector2Array()
	var halves := PackedFloat64Array()
	var rejoins := PackedFloat64Array()
	var minimum_half: float = INF
	for width: float in track.route_widths: minimum_half = minf(minimum_half,width*0.5)
	for i: int in range(track.route.size()):
		var tangent: Vector2 = (track.route[(i+1)%track.route.size()]-track.route[posmod(i-1,track.route.size())]).normalized()
		normals.append(tangent.orthogonal())
		halves.append(track.route_widths[i]*0.5 if track.route_widths.size() == track.route.size() else 5.0)
		var end_distance: float = minf(track.route_cumulative[i],track.route_length-track.route_cumulative[i])
		rejoins.append(smoothstep(0.0,12.0,end_distance))
	var uniform: bool = true
	for half: float in halves:
		if half != minimum_half: uniform = false; break
	return {"normals":normals,"halves":halves,"rejoins":rejoins,"minimum_half":minimum_half,"uniform":uniform}

static func lane(track: NativeTrack, fraction: float, constant_width: bool = false, rejoin_start: bool = true, recovery_m: float = RaceRules.CHECKPOINT_RECOVERY_M, basis: Dictionary = {}) -> PackedVector2Array:
	# Basis belongs only to this preparation. Preserve double scalar values and
	# the original ordered Vector2 multiplies; do not fold their rounding steps.
	if basis.is_empty(): basis = _lane_basis(track)
	var path := PackedVector2Array()
	var normals: PackedVector2Array = basis.normals
	var halves: PackedFloat64Array = basis.halves
	var rejoins: PackedFloat64Array = basis.rejoins
	for i: int in range(track.route.size()):
		var half: float = halves[i]
		# Include interior lanes which keep their offset as a road widens,
		# as well as the separate paths following its variable-width edges.
		if constant_width: half = minf(half,basis.minimum_half)
		var lateral: float = (half+recovery_m)*fraction
		path.append(track.route[i]+normals[i]*lateral*(rejoins[i] if rejoin_start else 1.0))
	path.append(path[0]); path.append(path[1])
	var result := PackedVector2Array()
	for point: Vector2 in path:
		if result.size() >= 3:
			var travelled: float = 0.0
			for index: int in range(result.size()-3,-1,-1):
				travelled += result[index].distance_to(result[index+1])
				if travelled > 20.0: break
				var hit: Variant = Geometry2D.segment_intersects_segment(result[index],result[index+1],result[-1],point)
				if hit is Vector2 and hit.distance_to(point) > 0.001:
					result.resize(index+1); result.append(hit); break
		result.append(point)
	return result

static func select(session: RefCounted, track: NativeTrack) -> PackedInt32Array:
	var crossings: Array[PackedFloat64Array] = []
	var lanes: Array[PackedVector2Array] = []
	var corners: Array[Dictionary] = session._road_corners(track)
	var hairpins: Array[Dictionary] = []
	for corner: Dictionary in corners:
		if float(corner.half_span) >= float(corner.road_half)*HAIRPIN_MITER_RATIO: hairpins.append(corner)
	var priorities := PackedInt32Array()
	for gate: int in range(session._centers.size()):
		var priority: int = 1
		for corner: Dictionary in corners:
			if absf(float(corner.distance)-session._progress[gate]) < 0.01:
				for hairpin: Dictionary in hairpins:
					var separation: float = absf(float(corner.distance)-float(hairpin.distance))
					separation = minf(separation,track.route_length-separation)
					if separation <= float(hairpin.reach)*2.0+float(hairpin.road_half)+RaceRules.CHECKPOINT_RECOVERY_M:
						priority = session._centers.size()+1
						break
				break
		priorities.append(priority)
	var route_bins: Dictionary = {}
	for i: int in range(track.route.size()):
		var key := Vector2i((track.route[i]/8.0).floor())
		if not route_bins.has(key): route_bins[key] = []
		route_bins[key].append(i)
	# A recovery lane can erase the very hairpin it should recover around.
	# Expanding an inner lane with a neighbouring wider road can erase it too.
	# Use interior road/kerb references for the required order; full recovery lanes
	# still prepare notices and ordinary/outer gate spans remain unchanged.
	var edge_steps: int = EDGE_HALF_STEPS if not hairpins.is_empty() else LANE_HALF_STEPS
	var edge_count: int = edge_steps*2+1
	var edge_margin: float = ROAD_EDGE_MARGIN_M if not hairpins.is_empty() else RaceRules.CHECKPOINT_RECOVERY_M
	var basis: Dictionary = _lane_basis(track)
	var lane_cache: Dictionary = {}
	var crossing_cache: Dictionary = {}
	var initial_widths: PackedByteArray = var_to_bytes(session._widths)
	for lane_index: int in range(edge_count*3):
		var path: PackedVector2Array = _cached_lane(track,float(lane_index%edge_count-edge_steps)/edge_steps,lane_index >= edge_count,lane_index < edge_count*2,edge_margin,basis,lane_cache)
		lanes.append(path)
		crossings.append(_cached_crossings(session,path,crossing_cache))
	for gate: int in range(session._centers.size()):
		if priorities[gate] == 1: continue
		var low: float = INF
		var high: float = -INF
		var valid: bool = true
		for lane_index: int in range(lanes.size()):
			if lane_index < edge_count: continue
			var event: float = crossings[lane_index][gate]
			if event < 0.0: valid = false; break
			var index: int = floori(event)
			var point: Vector2 = lanes[lane_index][index].lerp(lanes[lane_index][index+1],event-index)
			var lateral: float = (point-session._centers[gate]).dot(session._directions[gate].orthogonal())
			low = minf(low,lateral); high = maxf(high,lateral)
		if valid:
			var absolute: float = session._start_progress+session._progress[gate]
			var incoming: Vector2 = (session._centers[gate]-track._race_route_point(absolute-8.0)).normalized()
			var outgoing: Vector2 = (track._race_route_point(absolute+8.0)-session._centers[gate]).normalized()
			var inside: int = 1 if (outgoing-incoming).dot(session._directions[gate].orthogonal()) > 0.0 else 0
			var bound: float = maxf(0.0,high if inside == 1 else -low)+APEX_SLACK_M
			# Shortcut references may reduce recovery, never the physical road.
			session._widths[gate][inside] = maxf(session._road_widths[gate][inside],minf(session._widths[gate][inside],bound))
	var paved_crossings: Array[PackedFloat64Array] = []
	var edge_crossings: Array[PackedFloat64Array] = []
	var widths_changed: bool = initial_widths != var_to_bytes(session._widths)
	if widths_changed: crossing_cache.clear()
	for lane_index: int in range(lanes.size()):
		# Narrowed hairpin widths require new crossings. Otherwise the original
		# exact events remain valid, including nearest-crossing/tie order.
		var events: PackedFloat64Array = _cached_crossings(session,lanes[lane_index],crossing_cache) if widths_changed else crossings[lane_index]
		edge_crossings.append(events)
		if not hairpins.is_empty() and lane_index < edge_count: continue
		paved_crossings.append(events)
	if not hairpins.is_empty():
		var paved_lanes: Array[PackedVector2Array] = lanes.duplicate()
		lanes.clear(); crossings.clear()
		for lane_index: int in range(LANE_COUNT*3):
			var path: PackedVector2Array = _cached_lane(track,float(lane_index%LANE_COUNT-LANE_HALF_STEPS)/LANE_HALF_STEPS,lane_index >= LANE_COUNT,lane_index < LANE_COUNT*2,RaceRules.CHECKPOINT_RECOVERY_M,basis,lane_cache)
			lanes.append(path); crossings.append(_cached_crossings(session,path,crossing_cache))
		for lane_index: int in range(paved_lanes.size()):
			lanes.append(paved_lanes[lane_index]); crossings.append(edge_crossings[lane_index])
	else:
		# With no folded hairpins, edge and recovery passes have exactly the
		# same fractions, width mode, rejoin flag and recovery margin.
		crossings.assign(edge_crossings)
	var counts := PackedInt32Array()
	var previous := PackedInt32Array()
	var costs := PackedFloat32Array()
	var best: int = -1
	for gate: int in range(session._centers.size()):
		var weight: int = priorities[gate]
		var valid: bool = true
		var references: Array[PackedFloat64Array] = paved_crossings
		for lane_index: int in range(references.size()) if valid else []:
			if references[lane_index][gate] < 0.0: valid = false; break
		counts.append(weight if valid else 0); previous.append(-1)
		var width: Vector2 = session._widths[gate]
		costs.append(width.x+width.y)
		if not valid: continue
		for earlier: int in range(gate):
			if counts[earlier] == 0: continue
			var ordered: bool = true
			for events: PackedFloat64Array in paved_crossings:
				if events[earlier] >= events[gate]-0.00001: ordered = false; break
			if ordered and (counts[earlier]+weight > counts[gate] or (counts[earlier]+weight == counts[gate] and costs[earlier]+width.x+width.y < costs[gate])):
				counts[gate] = counts[earlier]+weight; previous[gate] = earlier
				costs[gate] = costs[earlier]+width.x+width.y
		if best < 0 or counts[gate] > counts[best] or (counts[gate] == counts[best] and costs[gate] < costs[best]): best = gate
	var selected := PackedInt32Array()
	while best >= 0:
		selected.append(best); best = previous[best]
	selected.reverse()
	# The nearest physical road can be the returning arm before this gate.
	# Bound that display-only projection along every accepted lane approach.
	var projections: Dictionary = {}
	for gate: int in range(session._centers.size()): session._notice_approaches.append({})
	for lane_index: int in range(lanes.size()):
		var path: PackedVector2Array = lanes[lane_index]
		var events: PackedFloat64Array = crossings[lane_index]
		# A recovery offset which misses a mandatory apex is itself a bypass.
		# Its partial approach must not hide the warning after a real shortcut.
		var complete: bool = true
		for gate: int in selected:
			if events[gate] < 0.0: complete = false; break
		if not complete: continue
		var previous_event: float = 0.0
		var accepted_event: float = 0.0
		for gate: int in selected:
			var event: float = events[gate]
			if event < 0.0: continue
			var reach: float = session._notice_reach[gate]
			var cells: Dictionary = session._notice_approaches[gate]
			# Runtime can accept an earlier valid crossing than the nearest
			# crossing used to select the common chain on a folded spline.
			# Protect the approach actually driven after that earlier crossing.
			var next_event: float = event
			for i: int in range(floori(accepted_event),path.size()-1):
				var fraction: float = session._crossing(gate,path[i],path[i+1])
				if fraction < 0.0 or i+fraction < accepted_event-0.000001: continue
				if session._inside(gate,path[i].lerp(path[i+1],fraction)):
					next_event = i+fraction; break
			for i: int in range(floori(accepted_event),mini(floori(next_event)+1,path.size()-1)):
				var a: Vector2 = path[i].lerp(path[i+1],clampf(accepted_event-i,0.0,1.0))
				var b: Vector2 = path[i].lerp(path[i+1],clampf(next_event-i,0.0,1.0))
				var steps: int = maxi(1,ceili(a.distance_to(b)*2.0))
				for step: int in range(steps+1): cells[Vector2i(a.lerp(b,float(step)/steps).floor())] = true
			accepted_event = next_event
			for i: int in range(floori(previous_event),mini(ceili(event)+1,path.size()-1)):
				var point: Vector2 = path[i]
				var progress: float = float(projections.get(point,NAN))
				if is_nan(progress):
					progress = _projection(track,point,route_bins)
					projections[point] = progress
				var ahead: float = wrapf(progress-session._start_progress-session._progress[gate],-track.route_length*0.5,track.route_length*0.5)
				reach = maxf(reach,ahead+1.0)
			session._notice_reach[gate] = reach
			previous_event = event
	return selected

static func _cached_lane(track: NativeTrack, fraction: float, constant_width: bool, rejoin_start: bool, recovery_m: float, basis: Dictionary, cache: Dictionary) -> PackedVector2Array:
	# On uniform-width routes min(half, minimum_half) is the same half.
	# Keep variable widths and every lane in the downstream ordered passes.
	var key: PackedByteArray = var_to_bytes([fraction,constant_width and not basis.uniform,rejoin_start,recovery_m])
	if not cache.has(key): cache[key] = lane(track,fraction,constant_width,rejoin_start,recovery_m,basis)
	return cache[key]

static func _cached_crossings(session: RefCounted, path: PackedVector2Array, cache: Dictionary) -> PackedFloat64Array:
	# Exact serialized points, including their order/rounding. Different lane
	# modes often produce identical paths; width changes discard this cache.
	var key: PackedByteArray = var_to_bytes(path)
	if not cache.has(key): cache[key] = _crossings(session,path)
	return cache[key]

static func _crossings(session: RefCounted, path: PackedVector2Array) -> PackedFloat64Array:
	var events := PackedFloat64Array()
	# Index segment bounds once per lane. Only segments overlapping a gate's
	# finite span can cross it; preserve ascending order for equal-distance ties.
	var bins: Dictionary = {}
	for i: int in range(path.size()-1):
		var low := Vector2i((path[i].min(path[i+1])/8.0).floor())
		var high := Vector2i((path[i].max(path[i+1])/8.0).floor())
		for y: int in range(low.y,high.y+1):
			for x: int in range(low.x,high.x+1):
				var cell := Vector2i(x,y)
				if not bins.has(cell): bins[cell] = []
				bins[cell].append(i)
	for gate: int in range(session._centers.size()):
		var event: float = -1.0
		var nearest: float = INF
		var center: Vector2 = session._centers[gate]
		var direction: Vector2 = session._directions[gate]
		var normal: Vector2 = direction.orthogonal()
		var widths: Vector2 = session._widths[gate]
		var left: Vector2 = center-normal*widths.x
		var right: Vector2 = center+normal*widths.y
		var low := Vector2i(((left.min(right)-Vector2.ONE*0.001)/8.0).floor())
		var high := Vector2i(((left.max(right)+Vector2.ONE*0.001)/8.0).floor())
		var candidates: Dictionary = {}
		for y: int in range(low.y,high.y+1):
			for x: int in range(low.x,high.x+1):
				for index: int in bins.get(Vector2i(x,y),[]): candidates[index] = true
		var ordered: Array = candidates.keys()
		ordered.sort()
		for i: int in ordered:
			var before: float = (path[i]-center).dot(direction)
			var after: float = (path[i+1]-center).dot(direction)
			var f: float = -before/(after-before) if before <= 0.0 and after > 0.0 else -1.0
			if f < 0.0: continue
			var p: Vector2 = path[i].lerp(path[i+1],f)
			var lateral: float = (p-center).dot(normal)
			if lateral < -widths.x or lateral > widths.y: continue
			if p.distance_squared_to(center) < nearest:
				nearest = p.distance_squared_to(center); event = i+f
		events.append(event)
	return events

static func _projection(track: NativeTrack, point: Vector2, bins: Dictionary) -> float:
	var key := Vector2i((point/8.0).floor())
	var best: float = INF
	var nearest: int = 0
	for y: int in range(-2,3):
		for x: int in range(-2,3):
			for index: int in bins.get(key+Vector2i(x,y),[]):
				var distance: float = point.distance_squared_to(track.route[index])
				if distance < best or (distance == best and index < nearest):
					best = distance; nearest = index
	# The unvisited cells are at least 16 m away. Sparse routes retain the
	# original exact global search when that bound cannot prove the result.
	if best > 256.0: nearest = track.nearest_route(point)
	best = INF
	var progress: float = track.route_cumulative[nearest]
	for offset: int in range(-1,2):
		var index: int = posmod(nearest+offset,track.route.size())
		var edge: Vector2 = track.route[(index+1)%track.route.size()]-track.route[index]
		var fraction: float = clampf((point-track.route[index]).dot(edge)/maxf(edge.length_squared(),0.000001),0.0,1.0)
		var distance: float = point.distance_squared_to(track.route[index]+edge*fraction)
		if distance < best:
			best = distance; progress = track.route_cumulative[index]+edge.length()*fraction
	return progress
