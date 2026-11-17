class_name TrackSession
extends RefCounted
## Ordered swept gates; no route-history/shortcut search per tick.
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
var last_progress: float = 0.0
var _widths: Array[Vector2] = []
var _road_widths: Array[Vector2] = []
var _centers := PackedVector2Array()
var _directions := PackedVector2Array()
var _progress := PackedFloat32Array()
var _notice_reach := PackedFloat32Array()
var _route_hints := PackedInt32Array()
var _start_progress: float = 0.0
var _layers: Array[bool] = []
var _finish_elevated: bool = false
var _finish_road_widths := Vector2.ZERO
var _finish_widths := Vector2.ZERO
var _spline_corridor: bool = false
var _notice_route_bins: Dictionary = {}
var _notice_approaches: Array[Dictionary] = []
var _notice_route_layers := PackedByteArray()
var _notice_layer_offsets := PackedInt32Array()
const NOTICE_LAYOUT_VERSION: int = 4
const NOTICE_CELL_M: float = 8.0
const GATE_LAYOUT_FIELDS: Array[String] = ["_start_progress","_finish_elevated","_finish_road_widths","_finish_widths","_spline_corridor","_centers","_directions","_progress","_widths","_road_widths","_notice_reach","_route_hints","_layers","_notice_route_bins","_notice_approaches","_notice_route_layers","_notice_layer_offsets"]
const LAYOUT_CACHE = preload("res://race/checkpoint_layout_cache.gd")

func _init(rate: int = 120, laps: int = RaceRules.LAPS) -> void:
	tick_rate = rate
	target_laps = laps

func prepare_cached(track: NativeTrack, cancelled: Callable) -> void:
	# Explicit preparation worker entry only. _configure/advance remain disk-free.
	if cancelled.call(): return
	var ready: bool = track._race_gates.get("rules_key","") == RaceRules.KEY and track._race_gates.get("notice_version",0) == NOTICE_LAYOUT_VERSION and track._race_gates.get("checkpoint_layout_version",0) == RaceRules.CHECKPOINT_LAYOUT_VERSION
	if ready: _configure(track); return
	var versions: Array = [RaceRules.KEY,NOTICE_LAYOUT_VERSION,RaceRules.CHECKPOINT_LAYOUT_VERSION]
	var key: String = LAYOUT_CACHE.key_for(track,versions)
	var cached: Dictionary = LAYOUT_CACHE.read(key)
	if not cached.layout.is_empty(): _configure(track,key,cached); return
	# The menu/canonical session dependency graph does not load this optional IO
	# helper. Only a worker cache miss resolves it, with no renderer resources.
	var disk: GDScript = load("res://race/checkpoint_layout_disk_cache.gd")
	var disk_hit: bool = false
	if LAYOUT_CACHE.current(cached.generation):
		cached.layout = disk.read_entry(key,track,versions)
		disk_hit = not cached.layout.is_empty()
	if cancelled.call(): return
	if disk_hit and not LAYOUT_CACHE.current(cached.generation): cached.layout = {}; disk_hit = false
	_configure(track,key,cached,false)
	if cancelled.call() or not LAYOUT_CACHE.current(cached.generation): return
	LAYOUT_CACHE.store(key,track._race_gates,cached.generation)
	if not disk_hit:
		disk.write_entry(key,track._race_gates,track,versions,func() -> bool: return cancelled.call() or not LAYOUT_CACHE.current(cached.generation))

func _configure(track: NativeTrack, supplied_key: String = "", supplied_cache: Dictionary = {}, retain_cache: bool = true) -> void:
	# Bake the gate corridor once. Acceptance visits only the current gate and
	# its neighbour, regardless of track length or total gate count.
	if track._race_gates.get("rules_key","") == RaceRules.KEY and track._race_gates.get("notice_version",0) == NOTICE_LAYOUT_VERSION and track._race_gates.get("checkpoint_layout_version",0) == RaceRules.CHECKPOINT_LAYOUT_VERSION:
		for field: String in GATE_LAYOUT_FIELDS:
			var value: Variant = track._race_gates[field]
			set(field,value.duplicate() if value is Array else value)
		initialized = true
		return
	var layout_key: String = supplied_key if not supplied_cache.is_empty() else LAYOUT_CACHE.key_for(track,[RaceRules.KEY,NOTICE_LAYOUT_VERSION,RaceRules.CHECKPOINT_LAYOUT_VERSION])
	var cached: Dictionary = supplied_cache if not supplied_cache.is_empty() else LAYOUT_CACHE.read(layout_key)
	if not cached.layout.is_empty():
		track._race_gates = cached.layout
		for field: String in GATE_LAYOUT_FIELDS:
			var value: Variant = track._race_gates[field]
			set(field,value.duplicate() if value is Array else value)
		initialized = true
		return
	_start_progress = track.route_progress(track.finish_center)
	_finish_elevated = track.elevated_at(track.finish_center,track.nearest_route(track.finish_center,0))
	if not track.creator_bridges.is_empty():
		_finish_elevated = CreatorBridges.initial_layer(track.creator_bridges,track.finish_center,atan2(track.finish_forward.x,track.finish_forward.y))
	var layer_distance: float = 0.0
	var route_elevated: bool = _finish_elevated
	var targets: Array[float] = []
	_spline_corridor = false
	for piece: Dictionary in track.metadata.get("creator_document",{}).get("pieces",[]):
		if piece.kind == "spline": _spline_corridor = true; break
	var count: int = maxi(4,ceili(track.route_length/(RaceRules.SPLINE_GATE_SPACING_M if _spline_corridor else 12.0)))
	var corners: Array[Dictionary] = _road_corners(track)
	if _spline_corridor:
		# Inspect folded bends more closely; the common legal-lane ordering
		# below still discards gates which would require an artificial loop.
		for distance: float in range(1,ceili(track.route_length),RaceRules.HAIRPIN_GATE_SPACING_M):
			for corner: Dictionary in corners:
				if float(corner.half_span) < float(corner.road_half)*SplineGateCorridor.HAIRPIN_MITER_RATIO: continue
				var separation: float = absf(distance-float(corner.distance))
				separation = minf(separation,track.route_length-separation)
				if separation <= float(corner.reach)*2.0+float(corner.road_half):
					targets.append(distance); break
	for i: int in range(1,count):
		var distance: float = track.route_length*i/count
		var overlaps_corner: bool = false
		if not _spline_corridor:
			for corner: Dictionary in corners:
				var separation: float = absf(distance-float(corner.distance))
				separation = minf(separation,track.route_length-separation)
				if separation < float(corner.reach): overlaps_corner = true; break
		if not overlaps_corner: targets.append(distance)
	for corner: Dictionary in corners: targets.append(corner.distance)
	targets.sort()
	var dirt: bool = track.metadata.get("creator_document",{}).get("surface","") == "dirt" or not track.metadata.has("creator_document")
	var coverage := preload("res://race/road_gate_coverage.gd").new(track)
	for distance: float in targets:
		var junction: Dictionary = {}
		for corner: Dictionary in corners:
			if is_equal_approx(distance,float(corner.distance)): junction = corner; break
		if junction.is_empty() and not _progress.is_empty() and distance-_progress[-1] < (0.5 if _spline_corridor else 3.0): continue
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
		else: direction = _bridge_gate_direction(track,center,direction,half+0.75)
		var normal: Vector2 = direction.orthogonal()
		var elevated: bool = track.elevated_at(center,low) if track.grid_width > 0 else false
		if not track.creator_bridges.is_empty():
			# A lower road can run parallel beneath a deck edge (Dust cloud).
			# Follow the same ramp-entry/layer continuity as the car instead of
			# inferring elevation from the tangent at this isolated gate.
			while layer_distance < distance:
				layer_distance = minf(distance,layer_distance+0.25)
				route_elevated = CreatorBridges.layer_at(track.creator_bridges,track._race_route_point(_start_progress+layer_distance),route_elevated)
			route_elevated = CreatorBridges.layer_at(track.creator_bridges,center,route_elevated)
			elevated = route_elevated
		_layers.append(elevated)
		var widths := Vector2(half+0.75,half+0.75)
		var allowed: Array = [0,2,5] if dirt else [0,5]
		var road_widths: Vector2 = _gate_road_spans(track,coverage,center,direction,half,elevated,allowed)
		if track.grid_width > 0: widths = road_widths+Vector2.ONE*RaceRules.CHECKPOINT_RECOVERY_M
		# A shallow excursion already loses grip/time. Allow extra inside
		# recovery space, fading it out before a tight hairpin can be cut.
		var approach: Vector2 = (center-track._race_route_point(absolute-8.0)).normalized()
		var departure: Vector2 = (track._race_route_point(absolute+8.0)-center).normalized()
		var turn: float = absf(approach.angle_to(departure))
		if turn > 0.01 and track.grid_width == 0:
			var allowance: float = 3.0*(1.0-smoothstep(deg_to_rad(30.0),deg_to_rad(60.0),turn))
			var inside: int = 1 if (departure-approach).dot(normal) > 0.0 else 0
			widths[inside] += allowance
			# Running wide costs distance; keep inside shortcut limits separate.
			widths[1-inside] += 6.0*smoothstep(0.01,0.08,turn)
		_centers.append(center)
		_route_hints.append(low)
		_directions.append(direction)
		_progress.append(distance)
		_widths.append(widths)
		_road_widths.append(road_widths)
		# An inside miter can project onto the outgoing road before it crosses
		# the gate. Bound that legal overlap before using route progress to
		# report a bypass which never intersects the gate's forward plane.
		var notice_reach: float = maxf(1.0,float(junction.get("reach",0.0)))
		for endpoint: Vector2 in [center-normal*widths.x,center+normal*widths.y]:
			var projected: float = track.route_progress(endpoint,low)
			var ahead: float = fposmod(projected-absolute+track.route_length*0.5,track.route_length)-track.route_length*0.5
			notice_reach = maxf(notice_reach,ahead+0.5)
		_notice_reach.append(notice_reach)
	if _spline_corridor:
		var selected: PackedInt32Array = SplineGateCorridor.select(self,track)
		for index: int in range(_centers.size()-1,-1,-1):
			if index in selected: continue
			_widths.remove_at(index); _road_widths.remove_at(index); _layers.remove_at(index)
			_centers.remove_at(index); _directions.remove_at(index); _progress.remove_at(index)
			_notice_reach.remove_at(index); _route_hints.remove_at(index)
			_notice_approaches.remove_at(index)
	_finish_road_widths = _gate_road_spans(track,coverage,track.finish_center,track.finish_forward,track.finish_half_width,_finish_elevated,[0,2,5] if dirt else [0,5])
	_finish_widths = _finish_road_widths+Vector2.ONE*1.5
	_prepare_notice_route(track)
	initialized = true
	var prepared: Dictionary = {"rules_key":RaceRules.KEY,"notice_version":NOTICE_LAYOUT_VERSION,"checkpoint_layout_version":RaceRules.CHECKPOINT_LAYOUT_VERSION}
	for field: String in GATE_LAYOUT_FIELDS:
		var value: Variant = get(field)
		prepared[field] = value.duplicate() if value is Array else value
	track._race_gates = prepared
	if retain_cache: LAYOUT_CACHE.store(layout_key,prepared,int(cached.generation))

func _gate_road_spans(track: NativeTrack, coverage: RefCounted, center: Vector2, direction: Vector2, half: float, elevated: bool, allowed: Array) -> Vector2:
	var raster := Vector2.ONE*half
	if track.grid_width > 0 and _gate_surface(track,center,elevated,allowed):
		# Stop only at the physical edge, never an authored-width scan cap.
		var normal: Vector2 = direction.orthogonal()
		for side: int in range(2):
			var span: float = 0.0
			var sign_value: float = -1.0 if side == 0 else 1.0
			while span < track.half_extent.length()*2.0 and _gate_surface(track,center+normal*span*sign_value,elevated,allowed): span += 0.05
			raster[side] = span
	return coverage.spans(center,direction,raster,elevated)

func _gate_surface(track: NativeTrack, point: Vector2, elevated: bool, allowed: Array) -> bool:
	if elevated:
		# cell_at deliberately treats empty upper cells as drivable fallback;
		# gate measurement must stop at the actual deck instead.
		var x: int = floori((point.x+track.half_extent.x)/track.cell_size)
		var y: int = floori((track.half_extent.y-point.y)/track.cell_size)
		return x >= 0 and y >= 0 and x < track.grid_width and y < track.grid_height and track.deck_cells[y*track.grid_width+x] in allowed
	return track.cell_at(point) in allowed or track.kerbs.height_at(point) > 0.00001

func _prepare_notice_route(track: NativeTrack) -> void:
	_prepare_notice_layers(track)
	# Index segments once, including long sparse fixture edges. A local
	# collision hint deliberately cannot jump across a shortcut; notices need
	# the road physically reached by the car, without scanning the whole lap.
	for index: int in range(track.route.size()):
		var a: Vector2 = track.route[index]
		var b: Vector2 = track.route[(index+1)%track.route.size()]
		var steps: int = maxi(1,ceili(a.distance_to(b)/(NOTICE_CELL_M*0.5)))
		var visited: Dictionary = {}
		for step: int in range(steps+1):
			var key := Vector2i((a.lerp(b,float(step)/steps)/NOTICE_CELL_M).floor())
			if visited.has(key): continue
			visited[key] = true
			if not _notice_route_bins.has(key): _notice_route_bins[key] = PackedInt32Array()
			_notice_route_bins[key].append(index)

func _prepare_notice_layers(track: NativeTrack) -> void:
	if track.creator_bridges.is_empty(): return
	# The car's X/Z and a tangent cannot identify a branch's layer: a ground
	# road can pass diagonally beneath an aligned bridge (Knot). Follow the
	# authored route from the finish, using the same ramp continuity as gates.
	# Subsegment states also support sparse routes without walking them per tick.
	_notice_layer_offsets.resize(track.route.size()*2)
	var first: int = 0
	for i: int in range(track.route.size()):
		if track.route_cumulative[i] <= _start_progress: first = i
	var layer: bool = _finish_elevated
	var start: Vector2 = track._race_route_point(_start_progress)
	var end: Vector2 = track.route[(first+1)%track.route.size()]
	var initial_steps: int = maxi(1,ceili(start.distance_to(end)/0.25))
	for step: int in range(1,initial_steps+1):
		layer = CreatorBridges.layer_at(track.creator_bridges,start.lerp(end,float(step)/initial_steps),layer)
	for offset: int in range(1,track.route.size()+1):
		var i: int = (first+offset)%track.route.size()
		var a: Vector2 = track.route[i]
		var b: Vector2 = track.route[(i+1)%track.route.size()]
		var steps: int = maxi(1,ceili(a.distance_to(b)/0.25))
		_notice_layer_offsets[i*2] = _notice_route_layers.size()
		_notice_layer_offsets[i*2+1] = steps
		for step: int in range(steps+1):
			layer = CreatorBridges.layer_at(track.creator_bridges,a.lerp(b,float(step)/steps),layer)
			_notice_route_layers.append(int(layer))

func _notice_layer_at(track: NativeTrack, index: int, fraction: float) -> bool:
	var point: Vector2 = track.route[index].lerp(track.route[(index+1)%track.route.size()],fraction)
	if _notice_layer_offsets.is_empty(): return track.elevated_at(point,index)
	var start: int = _notice_layer_offsets[index*2]
	var steps: int = _notice_layer_offsets[index*2+1]
	var previous: bool = bool(_notice_route_layers[start+floori(fraction*steps)])
	return CreatorBridges.layer_at(track.creator_bridges,point,previous)

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
		result.append({"distance":distance,"center":points[i],"direction":direction,"half_span":half_span,"road_half":half,"reach":reach})
	# A fitted spline changes tangent smoothly, even when its authored points
	# form a very tight reversal. Dense straight gates at that apex can demand
	# an artificial loop on a perfectly legal inside line. Treat the actual
	# interpolation knots like road corners, using their approach bisector.
	for piece: Dictionary in pieces:
		if piece.kind != "spline": continue
		var nodes: PackedVector2Array = SplineRoad.points(piece)
		for i: int in range(1,nodes.size()-1):
			var incoming: Vector2 = (nodes[i]-nodes[i-1]).normalized()
			var outgoing: Vector2 = (nodes[i+1]-nodes[i]).normalized()
			if incoming.dot(outgoing) >= 0.707: continue
			var direction: Vector2 = (incoming+outgoing).normalized()
			if direction.length_squared() < 0.5: continue
			var progress: float = track.route_progress(nodes[i])
			var distance: float = fposmod(progress-_start_progress,track.route_length)
			if distance <= 0.25 or distance >= track.route_length-0.25: continue
			var absolute: float = _start_progress+distance
			var forward: Vector2 = track._race_route_point(absolute+2.0)-track._race_route_point(absolute-2.0)
			if direction.dot(forward) < 0.0: direction = -direction
			var cosine: float = maxf(0.25,absf(direction.dot(incoming)))
			var half: float = float(piece.point_widths[i])*0.5
			var reach: float = maxf(3.0,(half+0.75)*sqrt(maxf(0.0,1.0-cosine*cosine))/cosine+2.0)
			var duplicate: bool = false
			for corner: Dictionary in result:
				if Vector2(corner.center).distance_to(nodes[i]) < 0.1: duplicate = true; break
			if not duplicate: result.append({"distance":distance,"center":nodes[i],"direction":direction,"half_span":half/cosine,"road_half":half,"reach":reach})
	return result

func _bridge_gate_direction(track: NativeTrack, center: Vector2, direction: Vector2, half_span: float) -> Vector2:
	# A smoothed route starts turning before the physical ramp ends. Its
	# tilted gate can straddle ground/deck even though its centre is ground.
	# Cross the ramp squarely so every lane reaches the same expected layer.
	var closest: float = INF
	var result: Vector2 = direction
	for span: Dictionary in track.creator_bridges:
		var local: Vector2 = CreatorBridges.local_point(span,center)
		if absf(local.y) > float(span.width)*0.5+CreatorBridges.RAIL: continue
		var separation: float = minf(absf(local.x),absf(local.x-float(span.length)))
		var axis: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(span.heading)))
		var reach: float = maxf(2.0,half_span*absf(axis.cross(direction))+0.25)
		if separation > reach or separation >= closest: continue
		var alignment: float = axis.dot(direction)
		if absf(alignment) < 0.75: continue
		closest = separation
		result = axis if alignment >= 0.0 else -axis
	return result

func _inside(index: int, point: Vector2) -> bool:
	var lateral: float = (point-_centers[index]).dot(_directions[index].orthogonal())
	return lateral >= -_widths[index].x and lateral <= _widths[index].y

func checkpoint_position(track: NativeTrack) -> Vector2:
	if next_checkpoint >= _centers.size(): return track.finish_center+track.finish_forward.orthogonal()*(_finish_widths.y-_finish_widths.x)*0.5
	# Draw the actual asymmetric span, including the inside recovery margin.
	var widths: Vector2 = _widths[next_checkpoint]
	return _centers[next_checkpoint]+_directions[next_checkpoint].orthogonal()*(widths.y-widths.x)*0.5
func checkpoint_direction(track: NativeTrack) -> Vector2:
	return _directions[next_checkpoint] if next_checkpoint < _directions.size() else track.finish_forward
func checkpoint_width(track: NativeTrack) -> float:
	if next_checkpoint >= _centers.size(): return _finish_widths.x+_finish_widths.y
	return _widths[next_checkpoint].x+_widths[next_checkpoint].y
func checkpoint_count() -> int: return _centers.size()
func checkpoint_elevated() -> bool:
	return _layers[next_checkpoint] if next_checkpoint < _layers.size() else _finish_elevated

func checkpoint_road_center(track: NativeTrack) -> Vector2:
	return _centers[next_checkpoint] if next_checkpoint < _centers.size() else track.finish_center
func checkpoint_road_spans(track: NativeTrack) -> Vector2:
	return _road_widths[next_checkpoint] if next_checkpoint < _road_widths.size() else _finish_road_widths
func checkpoint_acceptance_spans(track: NativeTrack) -> Vector2:
	return _widths[next_checkpoint] if next_checkpoint < _widths.size() else _finish_widths

func _crossing(index: int, from: Vector2, to: Vector2) -> float:
	var before: float = (from-_centers[index]).dot(_directions[index])
	var after: float = (to-_centers[index]).dot(_directions[index])
	if before > 0.0 or after <= 0.0: return -1.0
	return -before/(after-before)

func advance(track: NativeTrack, from: Vector2, to: Vector2, route_index: int, elevated: bool = false, previous_layer: int = -1) -> void:
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
		var crossing_layer: bool = _crossing_layer(track,from,to,fraction,route_index,elevated,previous_layer)
		var wrong_layer: bool = _layers[next_checkpoint] != crossing_layer
		if wrong_layer or not _inside(next_checkpoint,point):
			if point.distance_squared_to(_centers[next_checkpoint]) < 1600.0:
				# A lower road may cross the plane of a future deck gate. Only
				# warn on its intended route approach, not that earlier branch.
				var progress: float = _route_progress_near(track,point,route_index,int(crossing_layer))
				var offset: float = _notice_offset(track,progress)
				# A spline approach can cross this plane outside the gate before
				# its valid crossing. Wait until it leaves the prepared approach
				# envelope; wrong-layer misses still report immediately.
				if offset >= -_notice_reach[next_checkpoint] and (wrong_layer or not _spline_corridor or _notice_bypassed(track,point,progress)): missed_checkpoint = next_checkpoint
			break
		consumed = fraction
		next_checkpoint += 1
		missed_checkpoint = -1
	if next_checkpoint+1 < _centers.size():
		var later: float = _crossing(next_checkpoint+1,from,to)
		if later >= 0.0 and _inside(next_checkpoint+1,from.lerp(to,later)) and _layers[next_checkpoint+1] == _crossing_layer(track,from,to,later,route_index,elevated,previous_layer):
			# A returning arm can cross that later plane while the required
			# gate is still ahead. Such an early crossing is not a bypass.
			var point: Vector2 = from.lerp(to,later)
			if _notice_offset(track,_route_progress_near(track,point,route_index,int(_layers[next_checkpoint+1]))) >= 0.0 and not _on_notice_approach(point): missed_checkpoint = next_checkpoint
	_update_display_progress(track,to,route_index,int(elevated))
	if next_checkpoint < _centers.size() and missed_checkpoint < 0:
		# A cut can rejoin beyond a bend without ever crossing its gate plane
		# (or the next gate). Report it on reentry instead of at a later gate
		# or the finish. This read model never consumes or relaxes any gate.
		if _notice_bypassed(track,to,last_progress): missed_checkpoint = next_checkpoint
	# Crossing the start and the first dense gate in the same fast tick is
	# departure, not an incomplete lap. Arm only after meaningful progress.
	if route_distance >= minf(15.0,track.route_length*0.25): finish_armed = true
	var before: float = (from-track.finish_center).dot(track.finish_forward)
	var after: float = (to-track.finish_center).dot(track.finish_forward)
	if not finish_armed or before > 0.0 or after <= 0.0: return
	var crossing: float = -before/(after-before)
	var finish_point: Vector2 = from.lerp(to,crossing)
	var finish_lateral: float = (finish_point-track.finish_center).dot(track.finish_forward.orthogonal())
	if _crossing_layer(track,from,to,crossing,route_index,elevated,previous_layer) != _finish_elevated or finish_lateral < -_finish_widths.x or finish_lateral > _finish_widths.y:
		if next_checkpoint == _centers.size() and finish_point.distance_squared_to(track.finish_center) < 1600.0: missed_checkpoint = next_checkpoint
		return
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

func _notice_offset(track: NativeTrack, progress: float) -> float:
	# Signed relative distance keeps the grid behind the start from looking
	# like a bypass at the end of the lap.
	return fposmod(progress-_start_progress-_progress[next_checkpoint]+track.route_length*0.5,track.route_length)-track.route_length*0.5

func _on_notice_approach(point: Vector2) -> bool:
	if not _spline_corridor or next_checkpoint >= _notice_approaches.size(): return false
	# Legal offset lanes can project far along a returning arm. Protect their
	# actual approach, rather than delaying every warning by that whole distance.
	var key := Vector2i(point.floor())
	var cells: Dictionary = _notice_approaches[next_checkpoint]
	for y: int in range(-1,2):
		for x: int in range(-1,2):
			if cells.has(key+Vector2i(x,y)): return true
	return false

func _notice_bypassed(track: NativeTrack, point: Vector2, progress: float) -> bool:
	var offset: float = _notice_offset(track,progress)
	if not _spline_corridor: return offset > _notice_reach[next_checkpoint]
	return offset > 1.0 and not _on_notice_approach(point)

func _crossing_layer(track: NativeTrack, from: Vector2, to: Vector2, fraction: float, route_index: int, elevated: bool, previous_layer: int) -> bool:
	# A gate can precede a ramp boundary within the same fast simulation tick.
	# Preserve strict layer checks, using the state at the crossing rather than
	# the later endpoint. Unchanged layers need no additional sweep work.
	if previous_layer < 0 or previous_layer == int(elevated): return elevated
	var crossing: Vector2 = from.lerp(to,fraction)
	if track.creator_bridges.is_empty():
		return track.elevated_at(crossing,track.nearest_route(crossing,route_index))
	var layer: bool = CreatorBridges.layer_at(track.creator_bridges,from,previous_layer == 1)
	var steps: int = maxi(1,ceili(from.distance_to(crossing)/(track.cell_size*0.45)))
	for step: int in range(1,steps+1):
		layer = CreatorBridges.layer_at(track.creator_bridges,from.lerp(crossing,float(step)/steps),layer)
	return layer

func _route_progress_near(track: NativeTrack, point: Vector2, hint: int, layer: int = -1) -> float:
	# Keep the collision resolver's branch at overlapping roads. A fresh
	# nearest-vertex search can jump to a future bridge at the same position.
	var best: float = INF
	var progress: float = last_progress
	var approach_best: float = INF
	var approach_progress: float = last_progress
	var approach_reach: float = 0.0
	var check_layers: bool = layer >= 0 and (not track.creator_bridges.is_empty() or track.bridge_height != 0.0)
	var target: float = _progress[next_checkpoint] if next_checkpoint < _progress.size() else track.route_length
	var approach_low: float = (_progress[next_checkpoint-1]-_notice_reach[next_checkpoint-1] if next_checkpoint > 0 else -3.0)-target
	var approach_high: float = _notice_reach[next_checkpoint] if next_checkpoint < _notice_reach.size() else 1.0
	var hints: Array[int] = [hint]
	# A shortcut return can reach the required gate while the collision hint
	# still follows a distant branch. The last accepted gate anchors the
	# notice read model to the recovered road when it is physically closer.
	# Keep the simulation branch on ties at overlapping roads; never change
	# the collision resolver or use historical maximum progress for notices.
	if next_checkpoint > 0 and next_checkpoint-1 < _route_hints.size():
		hints.append(_route_hints[next_checkpoint-1])
	for candidate: int in hints:
		for offset: int in range(-1,2):
			var i: int = posmod(candidate+offset,track.route.size())
			var edge: Vector2 = track.route[(i+1)%track.route.size()]-track.route[i]
			var t: float = clampf((point-track.route[i]).dot(edge)/maxf(edge.length_squared(),0.000001),0.0,1.0)
			var distance: float = point.distance_squared_to(track.route[i]+edge*t)
			if distance < best-0.000001:
				best = distance
				progress = track.route_cumulative[i]+edge.length()*t
			if distance < approach_best-0.000001:
				var projected: float = track.route_cumulative[i]+edge.length()*t
				var approach_offset: float = wrapf(projected-_start_progress-target,-track.route_length*0.5,track.route_length*0.5)
				if approach_offset >= approach_low and approach_offset <= approach_high and (not check_layers or _notice_layer_at(track,i,t) == bool(layer)):
					approach_best = distance; approach_progress = projected
					approach_reach = (track.route_widths[i]*0.5 if track.route_widths.size() == track.route.size() else 5.0)+RaceRules.CHECKPOINT_RECOVERY_M
	# Preserve the simulation branch on exact overlaps, but recover from a
	# stale hint as soon as another road segment is physically closer.
	if best < 0.000001: return progress
	var key := Vector2i((point/NOTICE_CELL_M).floor())
	for y: int in range(-2,3):
		for x: int in range(-2,3):
			for i: int in _notice_route_bins.get(key+Vector2i(x,y),PackedInt32Array()):
				var edge: Vector2 = track.route[(i+1)%track.route.size()]-track.route[i]
				var t: float = clampf((point-track.route[i]).dot(edge)/maxf(edge.length_squared(),0.000001),0.0,1.0)
				var distance: float = point.distance_squared_to(track.route[i]+edge*t)
				if distance < best-0.000001:
					best = distance
					progress = track.route_cumulative[i]+edge.length()*t
				if distance < approach_best-0.000001:
					var projected: float = track.route_cumulative[i]+edge.length()*t
					var approach_offset: float = wrapf(projected-_start_progress-target,-track.route_length*0.5,track.route_length*0.5)
					if approach_offset >= approach_low and approach_offset <= approach_high and (not check_layers or _notice_layer_at(track,i,t) == bool(layer)):
						approach_best = distance; approach_progress = projected
						approach_reach = (track.route_widths[i]*0.5 if track.route_widths.size() == track.route.size() else 5.0)+RaceRules.CHECKPOINT_RECOVERY_M
	# Nearby arms can share both X/Z and the same road layer. Prefer the
	# required approach while the car is still in its recovery corridor;
	# outside it, the physically reached branch supplies bypass evidence.
	if approach_best <= approach_reach*approach_reach: return approach_progress
	return progress

func _update_display_progress(track: NativeTrack, point: Vector2, hint: int, layer: int = -1) -> void:
	# Display/notice progress only; acceptance remains swept gates.
	last_progress = _route_progress_near(track,point,hint,layer)
	var low: float = _progress[next_checkpoint-1] if next_checkpoint > 0 else 0.0
	var high: float = _progress[next_checkpoint] if next_checkpoint < _progress.size() else track.route_length
	route_distance = clampf(fposmod(last_progress-_start_progress,track.route_length),low,high)

func race_time_seconds() -> float:
	return lap_start_time if finished else float(elapsed_ticks)/tick_rate
