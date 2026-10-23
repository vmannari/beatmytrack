class_name SplineGateCorridor
extends RefCounted
## Select a common ordered gate chain for the full spline lane at preparation.
## Offset folds at a tight apex are trimmed; a driver need not follow a loop.
const LANE_HALF_STEPS: int = 28
const LANE_COUNT: int = LANE_HALF_STEPS*2+1

static func lane(track: NativeTrack, fraction: float, constant_width: bool = false, rejoin_start: bool = true) -> PackedVector2Array:
	var path := PackedVector2Array()
	var minimum_half: float = INF
	for width: float in track.route_widths: minimum_half = minf(minimum_half,width*0.5)
	for i: int in range(track.route.size()):
		var tangent: Vector2 = (track.route[(i+1)%track.route.size()]-track.route[posmod(i-1,track.route.size())]).normalized()
		var half: float = track.route_widths[i]*0.5 if track.route_widths.size() == track.route.size() else 5.0
		# Include interior lanes which keep their offset as a road widens,
		# as well as the separate paths following its variable-width edges.
		if constant_width: half = minf(half,minimum_half)
		var end_distance: float = minf(track.route_cumulative[i],track.route_length-track.route_cumulative[i])
		var lateral: float = (half+RaceRules.CHECKPOINT_RECOVERY_M)*fraction
		path.append(track.route[i]+tangent.orthogonal()*lateral*(smoothstep(0.0,12.0,end_distance) if rejoin_start else 1.0))
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
	var route_bins: Dictionary = {}
	for i: int in range(track.route.size()):
		var key := Vector2i((track.route[i]/8.0).floor())
		if not route_bins.has(key): route_bins[key] = []
		route_bins[key].append(i)
	for lane_index: int in range(LANE_COUNT*3):
		var path: PackedVector2Array = lane(track,float(lane_index%LANE_COUNT-LANE_HALF_STEPS)/LANE_HALF_STEPS,lane_index >= LANE_COUNT,lane_index < LANE_COUNT*2)
		lanes.append(path)
		var events := PackedFloat64Array()
		for gate: int in range(session._centers.size()):
			var event: float = -1.0
			var nearest: float = INF
			var center: Vector2 = session._centers[gate]
			var direction: Vector2 = session._directions[gate]
			var normal: Vector2 = direction.orthogonal()
			var widths: Vector2 = session._widths[gate]
			var before: float = (path[0]-center).dot(direction)
			for i: int in range(path.size()-1):
				var after: float = (path[i+1]-center).dot(direction)
				var fraction: float = -before/(after-before) if before <= 0.0 and after > 0.0 else -1.0
				before = after
				if fraction < 0.0: continue
				var point: Vector2 = path[i].lerp(path[i+1],fraction)
				var lateral: float = (point-center).dot(normal)
				if lateral < -widths.x or lateral > widths.y: continue
				var separation: float = point.distance_squared_to(center)
				if separation < nearest:
					nearest = separation; event = i+fraction
			events.append(event)
		crossings.append(events)
	var counts := PackedInt32Array()
	var previous := PackedInt32Array()
	var costs := PackedFloat32Array()
	var best: int = -1
	for gate: int in range(session._centers.size()):
		var valid: bool = true
		for events: PackedFloat64Array in crossings:
			if events[gate] < 0.0: valid = false; break
		counts.append(1 if valid else 0); previous.append(-1)
		var width: Vector2 = session._widths[gate]
		costs.append(width.x+width.y)
		if not valid: continue
		for earlier: int in range(gate):
			if counts[earlier] == 0: continue
			var ordered: bool = true
			for events: PackedFloat64Array in crossings:
				if events[earlier] >= events[gate]-0.00001: ordered = false; break
			if ordered and (counts[earlier]+1 > counts[gate] or (counts[earlier]+1 == counts[gate] and costs[earlier]+width.x+width.y < costs[gate])):
				counts[gate] = counts[earlier]+1; previous[gate] = earlier
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
		var previous_event: float = 0.0
		var accepted_event: float = 0.0
		for gate: int in selected:
			var event: float = events[gate]
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
