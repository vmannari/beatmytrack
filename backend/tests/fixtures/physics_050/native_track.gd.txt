class_name NativeTrack
extends PlaygroundData
## Native SI surface geometry. No knowledge of SS blocks, palettes or file layout.

const STORM_ROAD_GRIP: float = 0.85
const WINTER_ROAD_GRIP: float = 0.60

var cell_size: float
var grid_width: int
var grid_height: int
var cells := PackedInt32Array()
var deck_cells := PackedInt32Array()
var rectangles: Array
var deck_rectangles: Array
var route := PackedVector2Array()
var checkpoints: Array[Rect2] = []
var route_widths := PackedFloat32Array()
var route_cumulative := PackedFloat32Array()
var route_length: float = 0.0
var route_radii := PackedFloat32Array()
var route_cut_radii := PackedFloat32Array()
var bridge_axis := Vector2.ZERO
var bridge_height: float = 0.0
var metadata: Dictionary
var content_hash: String
var finish_center := Vector2.ZERO
var finish_forward := Vector2.ZERO
var finish_half_width: float = 0.0
var tyre_origins := PackedVector2Array()
var creator_bridges: Array = []
var hazard_objects: Array = []
var kerbs := RoadKerbs.new()
var snow_banks := SnowBanks.new()
var editor_overlay_mask: Image
var editor_road_mask: Image


static func read(path: String) -> NativeTrack:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema", "") not in ["surface-grid-v1", "surface-grid-v2"]:
		push_error("Invalid native track: " + path)
		return null
	return from_data(data, FileAccess.get_sha256(path))


static func from_data(data: Dictionary, hash_value: String) -> NativeTrack:
	# Trusted native data only. Creator imports are validated and compiled first.
	var track := NativeTrack.new()
	track.metadata = data
	track.tyre_origins = LooseTyres.positions(data.get("creator_document",{}))
	track.creator_bridges = data.get("creator_bridges",[])
	track.hazard_objects = data.get("creator_document",{}).get("objects",[])
	track.content_hash = hash_value
	track.identity = data.identity
	track.cell_size = float(data.cell_size)
	track.grid_width = int(data.grid_size[0])
	track.grid_height = int(data.grid_size[1])
	track.half_extent = Vector2(track.grid_width, track.grid_height) * track.cell_size * 0.5
	track.spawn = Vector2(data.spawn[0], data.spawn[1])
	track.spawn_heading = float(data.spawn_heading)
	track.finish_center = Vector2(data.finish.center[0], data.finish.center[1])
	track.finish_forward = Vector2(sin(float(data.finish.heading)), cos(float(data.finish.heading)))
	track.finish_half_width = float(data.finish.half_width)
	track.islands = []
	track.rectangles = data.surfaces
	track.deck_rectangles = data.deck
	track.cells.resize(track.grid_width * track.grid_height)
	track.deck_cells.resize(track.cells.size())
	track.deck_cells.fill(-1)
	track._expand(track.rectangles, track.cells)
	track._expand(track.deck_rectangles, track.deck_cells)
	for p: Array in data.route:
		track.route.append(Vector2(p[0], p[1]))
	track.route_widths = PackedFloat32Array(data.get("route_widths",[]))
	track._build_route_distance()
	for r: Array in data.checkpoints:
		track.checkpoints.append(Rect2(r[0], r[1], r[2], r[3]))
	track._build_validation_route()
	if not data.bridges.is_empty():
		track.bridge_axis = Vector2(data.bridges[0].axis[0], data.bridges[0].axis[1])
		track.bridge_height = float(data.bridges[0].height)
	track.kerbs.build(track)
	track.snow_banks.build(track)
	return track


func _build_route_distance() -> void:
	route_cumulative.resize(route.size())
	route_length = 0.0
	for i: int in range(route.size()):
		route_cumulative[i] = route_length
		route_length += route[i].distance_to(route[(i + 1) % route.size()])


func route_progress(point: Vector2, hint: int = -1) -> float:
	if route.size() < 2:
		return 0.0
	var nearest: int = nearest_route(point, hint)
	var best_distance: float = INF
	var best_progress: float = route_cumulative[nearest]
	# Check neighboring segments too: route vertices alone are not a valid
	# progress measurement on long or sharp pieces.
	for offset: int in range(-1, 2):
		var i: int = posmod(nearest + offset, route.size())
		var a: Vector2 = route[i]
		var b: Vector2 = route[(i + 1) % route.size()]
		var edge: Vector2 = b - a
		var t: float = clampf((point - a).dot(edge) / maxf(edge.length_squared(), 0.000001), 0.0, 1.0)
		var projected: Vector2 = a + edge * t
		var distance: float = point.distance_squared_to(projected)
		if distance < best_distance:
			best_distance = distance
			best_progress = route_cumulative[i] + edge.length() * t
	return best_progress


func _build_validation_route() -> void:
	route_radii.resize(route.size())
	route_cut_radii.resize(route.size())
	for i: int in range(route.size()):
		var outgoing: Vector2 = (route[(i + 1) % route.size()] - route[i]).normalized()
		route_radii[i] = _validation_radius(route[i], outgoing.orthogonal())
		var reach: float = minf(8.0, route_length * 0.05)
		var before: Vector2 = (route[i] - _race_route_point(route_cumulative[i] - reach)).normalized()
		var after: Vector2 = (_race_route_point(route_cumulative[i] + reach) - route[i]).normalized()
		var turn: float = before.cross(after)
		var tangent: Vector2 = (before + after).normalized()
		var inward: Vector2 = Vector2(-tangent.y,tangent.x) * signf(turn)
		route_cut_radii[i] = route_radii[i]
		if absf(turn) >= 0.02 and cell_at(route[i]) in [0,2,5]:
			var width: float = 0.0
			while width < 10.0 and cell_at(route[i] + inward * width) in [0,2,5]:
				width += maxf(cell_size,0.25)
			# Keep kerb/car overlap, but never borrow width from the outside.
			var baseline: float = clampf(float(metadata.get("representative_width_m",9.0)) * 0.5,3.0,10.0)
			route_cut_radii[i] = maxf(width,baseline) + 2.0




func project_race_route(point: Vector2, previous: float = NAN, motion: Vector2 = Vector2.ZERO) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = INF
	var continuity_margin: float = clampf(float(metadata.get("representative_width_m", 9.0)) * 0.5 + 1.0, 4.0, 11.0)
	for i: int in range(route.size()):
		var edge: Vector2 = route[(i + 1) % route.size()] - route[i]
		var t: float = clampf((point - route[i]).dot(edge) / maxf(edge.length_squared(), 0.000001), 0.0, 1.0)
		var distance: float = point.distance_to(route[i] + edge * t)
		var progress: float = route_cumulative[i] + edge.length() * t
		var delta: float = 0.0 if is_nan(previous) else wrapf(progress - previous, -route_length * 0.5, route_length * 0.5)
		if delta < -minf(12.0, route_length * 0.1) and motion.dot(edge) > 0.0:
			delta += route_length
		# Prefer the current branch at a crossing or beside a hairpin. Unlike
		# a vertex-count search window this behaves the same on sparse routes.
		var score: float = distance + minf(absf(delta) * 0.15, continuity_margin)
		if absf(delta) > 4.0 and delta * motion.dot(edge) < 0.0: score += 4.0
		if score < best_score:
			best_score = score
			best = {"progress":progress, "delta":delta, "distance":distance, "index":i}
	return best


func crosses_hairpin_infield(from: Vector2, to: Vector2) -> bool:
	# The constructed road is authoritative for small hairpins: the smoothed
	# lap route and a fixed distance-saving threshold can swallow their island.
	for piece: Dictionary in metadata.get("creator_document",{}).get("pieces",[]):
		if piece.kind != "hairpin": continue
		var origin := Vector2(piece.position[0],piece.position[1])
		var angle: float = deg_to_rad(float(piece.heading))
		var side: float = -1.0 if piece.flip else 1.0
		var a: Vector2 = (from-origin).rotated(-angle)
		var b: Vector2 = (to-origin).rotated(-angle)
		a.y *= side
		b.y *= side
		var radius: float = piece.radius
		if (a.y-radius)*(b.y-radius) > 0.0 or absf(b.y-a.y) < 0.000001: continue
		var fraction: float = (radius-a.y)/(b.y-a.y)
		if fraction <= 0.0 or fraction > 1.0: continue
		var crossing: Vector2 = a.lerp(b,fraction)
		# 0.75m kerb plus half the standard car width: crossing must put
		# the whole car clear of the inside kerb, not merely a wheel on grass.
		var clearance: float = 1.55
		var inner: float = radius-float(piece.width)*0.5-clearance
		if inner <= 0.0 or crossing.x < 0.0 or crossing.x > float(piece.length)+inner: continue
		var world: Vector2 = from.lerp(to,fraction)
		if not _clear_of_road(world,0.8): continue
		return true
	return false


func _clear_of_road(point: Vector2, clearance: float) -> bool:
	if kerbs.height_at(point) > 0.0: return false
	var cell := Vector2i(floori((point.x+half_extent.x)/cell_size),floori((half_extent.y-point.y)/cell_size))
	var reach: int = ceili(clearance/cell_size)+1
	for y: int in range(maxi(0,cell.y-reach),mini(grid_height,cell.y+reach+1)):
		for x: int in range(maxi(0,cell.x-reach),mini(grid_width,cell.x+reach+1)):
			var index: int = y*grid_width+x
			if cells[index] not in [0,2,5] and (deck_cells.is_empty() or deck_cells[index] not in [0,2,5]): continue
			var bounds := Rect2(Vector2(x*cell_size-half_extent.x,half_extent.y-(y+1)*cell_size),Vector2.ONE*cell_size)
			if point.distance_to(point.clamp(bounds.position,bounds.end)) <= clearance: return false
	return true


func has_cut_gap(previous: float, advance: float, driven: PackedVector2Array) -> bool:
	# Progress estimates can catch up after a sharp bend. A penalty also
	# needs spatial evidence: road was bypassed beyond its kerb tolerance,
	# not merely projected late after the car already drove alongside it.
	for i: int in range(route.size()):
		var edge: Vector2 = route[(i + 1) % route.size()] - route[i]
		var steps: int = maxi(1, ceili(edge.length() / 2.0))
		for step: int in range(steps):
			var fraction: float = float(step) / steps
			var distance: float = fposmod(route_cumulative[i] + edge.length() * fraction - previous, route_length)
			if distance > advance: continue
			var point: Vector2 = route[i] + edge * fraction
			var closest: float = INF
			var driven_point := Vector2.ZERO
			for j: int in range(driven.size() - 2, -1, -1):
				var candidate: Vector2 = Geometry2D.get_closest_point_to_segment(point, driven[j], driven[j + 1])
				var separation: float = point.distance_to(candidate)
				if separation < closest:
					closest = separation
					driven_point = candidate
				if closest <= route_cut_radii[i] + 1.0: break
			if closest <= route_cut_radii[i] + 1.0: continue
			# Distance alone cannot distinguish cutting inside from running wide.
			# Measure bend direction over metres, not a number of route vertices.
			var progress: float = route_cumulative[i] + edge.length() * fraction
			var reach: float = minf(8.0, route_length * 0.05)
			var incoming: Vector2 = (point - _race_route_point(progress - reach)).normalized()
			var outgoing: Vector2 = (_race_route_point(progress + reach) - point).normalized()
			var turn: float = incoming.cross(outgoing)
			if absf(turn) < 0.02: continue
			var tangent: Vector2 = (incoming + outgoing).normalized()
			var inside: float = tangent.cross(driven_point - point) * signf(turn)
			# Outside samples provide no cut evidence. They must not veto a
			# separate inside bypass within the same excursion.
			if inside < -1.0: continue
			if inside > 1.0: return true
	return false


func _race_route_point(distance: float) -> Vector2:
	var wrapped: float = fposmod(distance, route_length)
	var low: int = 0
	var high: int = route.size() - 1
	while low < high:
		var middle: int = (low + high + 1) / 2
		if route_cumulative[middle] <= wrapped: low = middle
		else: high = middle - 1
	var edge: Vector2 = route[(low + 1) % route.size()] - route[low]
	return route[low] + edge * clampf((wrapped - route_cumulative[low]) / maxf(edge.length(), 0.000001), 0.0, 1.0)


func _validation_radius(point: Vector2, normal: Vector2) -> float:
	# Measure the local road, including native kerb cells and dirt circuits.
	# Bound intersection widening so a crossing cannot swallow a whole loop.
	var baseline: float = clampf(float(metadata.get("representative_width_m", 9.0)) * 0.5, 3.0, 10.0)
	var half_width: float = 0.0
	if cell_size > 0.0 and cell_at(point) in [0, 2, 5]:
		for side: float in [-1.0, 1.0]:
			var width: float = 0.0
			while width < 10.0 and cell_at(point + normal * side * width) in [0, 2, 5]:
				width += maxf(cell_size, 0.25)
			half_width = maxf(half_width, width)
	else:
		half_width = baseline
	# 0.75 m raised creator kerb + car overlap and raster tolerance.
	return maxf(half_width, 3.0) + 2.0


func _expand(rects: Array, target: PackedInt32Array) -> void:
	for r: Array in rects:
		for y: int in range(int(r[1]), int(r[1] + r[3])):
			for x: int in range(int(r[0]), int(r[0] + r[2])):
				target[y * grid_width + x] = int(r[4])


func cell_at(point: Vector2, elevated: bool = false) -> int:
	var x: int = floori((point.x + half_extent.x) / cell_size)
	var y: int = floori((half_extent.y - point.y) / cell_size)
	if x < 0 or y < 0 or x >= grid_width or y >= grid_height:
		return 4
	var index: int = y * grid_width + x
	if elevated:
		return deck_cells[index] if deck_cells[index] >= 0 else 0
	return cells[index]


func has_overhead_bridge(point: Vector2, current_layer_elevated: bool) -> bool:
	if current_layer_elevated:
		return false
	if CreatorBridges.at_any(creator_bridges,point):
		return true
	var x: int = floori((point.x + half_extent.x) / cell_size)
	var y: int = floori((half_extent.y - point.y) / cell_size)
	return x >= 0 and y >= 0 and x < grid_width and y < grid_height and deck_cells[y * grid_width + x] >= 0


func nearest_route(point: Vector2, previous: int = -1) -> int:
	var best: int = 0 if previous < 0 else previous
	var distance: float = INF
	# Local continuity keeps a crossing from switching to its other route branch.
	var count: int = route.size() if previous < 0 else 25
	for offset: int in range(count):
		var i: int = offset if previous < 0 else posmod(previous + offset - 8, route.size())
		var d: float = route[i].distance_squared_to(point)
		if d < distance:
			distance = d
			best = i
	return best


func elevated_at(point: Vector2, route_index: int) -> bool:
	if CreatorBridges.at_any(creator_bridges,point):
		var forward: Vector2 = route[(route_index+1)%route.size()]-route[route_index]
		return CreatorBridges.initial_layer(creator_bridges,point,atan2(forward.x,forward.y))
	if bridge_height == 0.0:
		return false
	var tangent: Vector2 = (route[(route_index + 1) % route.size()] - route[route_index]).normalized()
	var x: int = floori((point.x + half_extent.x) / cell_size)
	var y: int = floori((half_extent.y - point.y) / cell_size)
	return x >= 0 and y >= 0 and x < grid_width and y < grid_height and deck_cells[y * grid_width + x] >= 0 and absf(tangent.dot(bridge_axis)) > 0.75


func tire_pickup(state: VehicleState) -> float:
	match cell_at(state.position, state.track_elevated):
		1: return 0.5 # Grass deposits less than loose dirt/sand.
		2: return 1.0 # Native dirt includes the imported sand surface.
	return 0.0


func tire_fluids(state: VehicleState) -> Vector2:
	if state.track_elevated or state.jump_height > 0.0: return Vector2.ZERO
	var coating := Vector2(0.0, 1.0 if cell_at(state.position) in [3,6] else 0.0)
	for object: Dictionary in hazard_objects:
		if object.kind not in ["oil","puddle"]: continue
		if not CreatorObjects.contains(object,state.position): continue
		if object.kind == "oil": coating.x = 1.0
		if object.kind == "puddle": coating.y = 1.0
	return coating


func water_depth(point: Vector2) -> float:
	# Average a bounded footprint to ease both sides of a raster shoreline.
	var depth: float = 0.0
	for y: int in range(-4,5):
		for x: int in range(-4,5):
			var sample: Vector2 = point + Vector2(x,y)*0.35
			var grid: Vector2 = Vector2((sample.x+half_extent.x)/cell_size, (half_extent.y-sample.y)/cell_size)-Vector2(0.5,0.5)
			var fraction: Vector2 = grid-grid.floor()
			var center: Vector2 = Vector2((floorf(grid.x)+0.5)*cell_size-half_extent.x,half_extent.y-(floorf(grid.y)+0.5)*cell_size)
			var upper: float = lerpf(_water_cell_depth(center),_water_cell_depth(center+Vector2(cell_size,0)),fraction.x)
			var lower: float = lerpf(_water_cell_depth(center-Vector2(0,cell_size)),_water_cell_depth(center+Vector2(cell_size,-cell_size)),fraction.x)
			depth += lerpf(upper,lower,fraction.y)
	return depth / 81.0


func _water_cell_depth(point: Vector2) -> float:
	var material: int = cell_at(point)
	return 0.48 if material == 3 else (0.12 if material == 6 else 0.0)


func collision_elevated_at(point: Vector2, route_index: int, radius: float, previous_layer: int = -1) -> bool:
	if CreatorBridges.at_any(creator_bridges,point,radius):
		if previous_layer >= 0: return CreatorBridges.layer_at(creator_bridges,point,previous_layer == 1,radius)
		return elevated_at(point,route_index)
	if elevated_at(point, route_index):
		return true
	if bridge_height == 0.0:
		return false
	var tangent: Vector2 = (route[(route_index + 1) % route.size()] - route[route_index]).normalized()
	if absf(tangent.dot(bridge_axis)) <= 0.75:
		return false
	# The upper branch must see a rail tip as soon as the car's footprint
	# touches it. Waiting for the centre to enter the deck enables a rail
	# inside the car. Route progression still separates the lower crossing.
	# Extend only along the bridge axis, preserving the native transverse
	# outline so a car beneath a side edge does not collide with upper rails.
	var steps: int = ceili(radius / (cell_size * 0.5))
	for i: int in range(1, steps + 1):
		var offset: Vector2 = bridge_axis * minf(radius, i * cell_size * 0.5)
		if elevated_at(point + offset, route_index) or elevated_at(point - offset, route_index):
			return _contact(point, radius, true).z > 0.0
	return false


func surface_factors(state: VehicleState) -> Vector2:
	var base: Vector2 = _native_surface_factors(state)
	var effects: Vector2 = TrackHazards.factors(state,hazard_objects)
	return Vector2(base.x*effects.x,base.y+effects.y)


func off_road_rumble(state: VehicleState) -> float:
	# Presentation roughness is independent of longitudinal resistance: loose
	# sand and grass are equally uneven even though their drag/grip differ.
	return 1.0 if cell_at(state.position,state.track_elevated) in [1,2] else 0.0


func _native_surface_factors(state: VehicleState) -> Vector2:
	var speed: float = state.velocity.length()
	match cell_at(state.position, state.track_elevated):
		0:
			var theme: String = str(metadata.get("theme", "pine"))
			if theme == "desert": return Vector2(0.94, 0.35) # Firm sand road, not deep roadside soil.
			return Vector2(WINTER_ROAD_GRIP if theme == "winter" else STORM_ROAD_GRIP if theme == "storm" else 1.0, 0.0)
		1: return Vector2(0.65, 2.0 + speed * 0.65)
		2: return Vector2(0.8, 2.0)
		5: return Vector2(0.95, 0.4)
		6: return Vector2(0.65, 0.5 + speed * 1.5)
		3: return Vector2(0.55, 0.5 + speed * 2.5)
		7: return Vector2(0.65, 2.0 + speed * 0.9) # Slows even under power, but allows escape from rest.
	return Vector2(1.0, 0.0)


func resolve(state: VehicleState, from: Vector2, config: HandlingConfig) -> void:
	state.route_index = nearest_route(from, state.route_index)
	state.track_elevated = collision_elevated_at(from, state.route_index, config.collision_radius,1 if state.track_elevated else 0)
	# Circle against native occupied cells, substeps shorter than half a cell.
	# Stable row order and bounded path sampling prevent thin-wall tunnelling.
	var movement: Vector2 = state.position - from
	var steps: int = maxi(1, ceili(movement.length() / (cell_size * 0.45)))
	var accepted: Vector2 = from
	var contact: Vector3 = _contact(from, config.collision_radius, state.track_elevated)
	for step_index: int in range(1, steps + 1):
		var point: Vector2 = from + movement * (float(step_index) / steps)
		var next_route: int = nearest_route(point, state.route_index)
		var next_elevated: bool = collision_elevated_at(point, next_route, config.collision_radius,1 if state.track_elevated else 0)
		var next_contact: Vector3 = _contact(point, config.collision_radius, next_elevated)
		if next_contact.z > 0.0:
			# A pre-existing overlap must not freeze outward movement. Require
			# non-increasing penetration against the same wall at each step.
			# New or deeper contacts still stop at the last accepted position.
			# Compare penetration on the candidate layer. An existing rail
			# overlap can straddle a layer boundary during outward recovery.
			var previous_contact: Vector3 = contact if next_elevated == state.track_elevated else _contact(accepted, config.collision_radius, next_elevated)
			var escaping: bool = previous_contact.z > 0.0
			var blocking_normal := Vector2(next_contact.x, next_contact.y)
			if escaping:
				var blocker: Vector2 = _escape_blocker(accepted, point, config.collision_radius, next_elevated)
				if blocker != Vector2.ZERO:
					escaping = false
					blocking_normal = blocker
			if not escaping:
				state.position = accepted
				_bounce(state, blocking_normal, config)
				# Consume the remaining tangential displacement instead of discarding
				# the whole step. Sweep it too, so sliding cannot tunnel past corners.
				var remaining: Vector2 = from + movement - accepted
				var slide: Vector2 = remaining - blocking_normal * remaining.dot(blocking_normal)
				var slide_steps: int = maxi(1, ceili(slide.length() / (cell_size * 0.45)))
				var slide_from: Vector2 = accepted
				for i: int in range(1, slide_steps + 1):
					var candidate: Vector2 = slide_from + slide * (float(i) / slide_steps)
					var candidate_route: int = nearest_route(candidate, state.route_index)
					var candidate_layer: bool = collision_elevated_at(candidate, candidate_route, config.collision_radius,1 if state.track_elevated else 0)
					if _contact(candidate, config.collision_radius, candidate_layer).z > 0.0:
						# Shallow flat-wall overlap can rub along its face. Do not
						# project an embedded corner contact around a rail tip.
						var flat_face: bool = absf(blocking_normal.x) > 0.99999 or absf(blocking_normal.y) > 0.99999
						if not flat_face or _contact(state.position, config.collision_radius, candidate_layer).z <= 0.0 or _escape_blocker(state.position, candidate, config.collision_radius, candidate_layer) != Vector2.ZERO:
							# A second obstacle can block the tangent. Do not bank
							# the rejected speed and release it after alignment.
							var tangent: Vector2 = slide.normalized()
							var completed: float = clampf(state.position.distance_to(slide_from) / maxf(slide.length(), 0.000001), 0.0, 1.0)
							state.velocity -= tangent * state.velocity.dot(tangent) * (1.0 - completed)
							var probe: Vector2 = state.position + state.velocity * VehicleSimulation.STEP
							var probe_layer: bool = collision_elevated_at(probe, nearest_route(probe, state.route_index), config.collision_radius,1 if state.track_elevated else 0)
							if _contact(probe, config.collision_radius, probe_layer).z > 0.0 and (_contact(state.position, config.collision_radius, probe_layer).z <= 0.0 or _escape_blocker(state.position, probe, config.collision_radius, probe_layer) != Vector2.ZERO):
								state.velocity = Vector2.ZERO
							break
					state.position = candidate
					state.route_index = candidate_route
					state.track_elevated = candidate_layer
				return
		accepted = point
		contact = next_contact
		state.route_index = next_route
		state.track_elevated = next_elevated
	state.position = accepted


func collision_normal(point: Vector2, radius: float, elevated: bool) -> Vector2:
	var contact: Vector3 = _contact(point, radius, elevated)
	return Vector2(contact.x, contact.y)


func overlaps_obstacle(point: Vector2, radius: float, elevated: bool) -> bool:
	if not elevated:
		for p: Vector2 in tyre_origins:
			if point.distance_to(p) < radius+LooseTyres.RADIUS: return true
	# A symmetric overlap may have a zero normal; depth is authoritative.
	return _contact(point,radius,elevated).z > 0.0


func _escape_blocker(from: Vector2, point: Vector2, radius: float, elevated: bool) -> Vector2:
	# Reducing total overlap must not hide entry into another cell/barrier.
	# Each obstacle must keep/reduce penetration (1 um tolerance); coplanar
	# neighboring wall cells share one plane rather than separate corner contacts.
	var cx: int = floori((point.x + half_extent.x) / cell_size)
	var cy: int = floori((half_extent.y - point.y) / cell_size)
	var reach: int = ceili(radius / cell_size) + 1
	var support: Vector3 = _support_plane(from, radius, elevated)
	var support_normal := Vector2(support.x, support.y)
	var span: int = CreatorBridges.span_at(creator_bridges,point) if elevated else -1
	for y: int in range(cy - reach, cy + reach + 1):
		for x: int in range(cx - reach, cx + reach + 1):
			var center := Vector2((x + 0.5) * cell_size - half_extent.x, half_extent.y - (y + 0.5) * cell_size)
			if span >= 0 and not CreatorBridges.contains(creator_bridges[span],center) and not CreatorBridges.shares_span(creator_bridges,point,center): continue
			if cell_at(center, elevated) not in [4]: continue
			var low: Vector2 = center - Vector2.ONE * cell_size * 0.5
			var high: Vector2 = center + Vector2.ONE * cell_size * 0.5
			var offset: Vector2 = point - point.clamp(low, high)
			var before: float = maxf(0.0, radius - from.distance_to(from.clamp(low, high)))
			var after: float = maxf(0.0, radius - offset.length())
			if after > before + 0.000001:
				# Adjacent cells on one flat wall are one contact surface. Sliding
				# transfers overlap between cells without going deeper into it.
				var nearest: Vector2 = point.clamp(low, high)
				if support_normal != Vector2.ZERO and absf(nearest.dot(support_normal) - support.z) < 0.000001:
					if point.dot(support_normal) >= from.dot(support_normal) - 0.000001:
						continue
					return support_normal
				var normal: Vector2 = offset.normalized() if offset != Vector2.ZERO else (from - center).normalized()
				# At a cell corner the destination normal can already be tangent
				# to incoming motion; use the entry normal to reject that motion.
				if normal.dot(point - from) >= 0.0:
					normal = (from - from.clamp(low, high)).normalized()
				return normal
	return Vector2.ZERO


func _support_plane(point: Vector2, radius: float, elevated: bool) -> Vector3:
	var cx: int = floori((point.x + half_extent.x) / cell_size)
	var cy: int = floori((half_extent.y - point.y) / cell_size)
	var reach: int = ceili(radius / cell_size) + 1
	var distance: float = radius
	var result := Vector3.ZERO
	var span: int = CreatorBridges.span_at(creator_bridges,point) if elevated else -1
	for y: int in range(cy - reach, cy + reach + 1):
		for x: int in range(cx - reach, cx + reach + 1):
			var center := Vector2((x+0.5)*cell_size-half_extent.x, half_extent.y-(y+0.5)*cell_size)
			if span >= 0 and not CreatorBridges.contains(creator_bridges[span],center) and not CreatorBridges.shares_span(creator_bridges,point,center): continue
			if cell_at(center, elevated) not in [4]: continue
			var nearest: Vector2 = point.clamp(center - Vector2.ONE*cell_size*0.5, center + Vector2.ONE*cell_size*0.5)
			var offset: Vector2 = point - nearest
			if offset.length() < distance and offset.length_squared() > 0.000001:
				distance = offset.length()
				var normal: Vector2 = offset / distance
				result = Vector3(normal.x, normal.y, nearest.dot(normal))
	return result


func _contact(point: Vector2, radius: float, elevated: bool) -> Vector3:
	# XY is the outward normal; Z is summed squared cell penetration. The latter
	# stays positive even where opposing cell normals cancel (inside a solid).
	var cx: int = floori((point.x + half_extent.x) / cell_size)
	var cy: int = floori((half_extent.y - point.y) / cell_size)
	var reach: int = ceili(radius / cell_size) + 1
	var total := Vector2.ZERO
	var overlap: float = 0.0
	var fallback := Vector2.RIGHT
	var layer: PackedInt32Array = deck_cells if elevated else cells
	var span: int = CreatorBridges.span_at(creator_bridges,point) if elevated else -1
	var first_x: int = cx - reach
	var end_x: int = cx + reach + 1
	# One native scan handles completely clear row bands (common around loose
	# tyre piles). The band includes extra columns, so it can only give a
	# conservative false positive; a negative proves the whole query is clear.
	if first_x >= 0 and end_x <= grid_width and cy-reach >= 0 and cy+reach < grid_height:
		if not layer.slice((cy-reach)*grid_width+first_x,(cy+reach)*grid_width+end_x).has(4):
			return Vector3.ZERO
	for y: int in range(cy - reach, cy + reach + 1):
		var row_inside: bool = y >= 0 and y < grid_height
		var row: int = y * grid_width
		# Native packed-array search rejects empty rows before constructing any
		# world positions. Read current cells, so edits cannot leave a stale cache.
		if row_inside and first_x >= 0 and end_x <= grid_width:
			if not layer.slice(row+first_x,row+end_x).has(4): continue
		for x: int in range(first_x, end_x):
			# Outside the grid is solid, on both levels. Only material 4 blocks.
			if row_inside and x >= 0 and x < grid_width and layer[row+x] != 4:
				continue
			var center := Vector2((x + 0.5) * cell_size - half_extent.x, half_extent.y - (y + 0.5) * cell_size)
			if span >= 0 and not CreatorBridges.contains(creator_bridges[span],center) and not CreatorBridges.shares_span(creator_bridges,point,center): continue
			var nearest: Vector2 = point.clamp(center - Vector2.ONE * cell_size * 0.5, center + Vector2.ONE * cell_size * 0.5)
			var offset: Vector2 = point - nearest
			if offset.length_squared() < radius * radius:
				var depth: float = radius - offset.length()
				overlap += depth * depth
				var outward: Vector2 = offset.normalized() if offset.length_squared() > 0.000001 else (point - center).normalized()
				total += outward * depth
				if outward != Vector2.ZERO: fallback = outward
	var normal: Vector2 = total.normalized() if total.length_squared() > 0.00000001 else (fallback if overlap > 0.0 else Vector2.ZERO)
	return Vector3(normal.x, normal.y, overlap)


func step_props(state: VehicleState, from: Vector2, config: HandlingConfig, step_seconds: float) -> void:
	LooseTyres.step(state,tyre_origins,_contact,from,config,step_seconds)
	LightProps.step(state,hazard_objects,_contact,from,step_seconds,config.mass,config.collision_radius)


func launch_jump(state: VehicleState, previous: Vector2) -> void:
	TrackHazards.launch(state,previous,hazard_objects)


func kerb_heights(state: VehicleState, config: HandlingConfig) -> Vector4:
	if state.track_elevated or state.jump_height > 0.0: return Vector4.ZERO
	var axle: Vector2 = state.forward()*config.wheelbase*0.5
	var side: Vector2 = state.right()*(config.track_width*0.5)
	return Vector4(kerbs.height_at(state.position+axle-side),kerbs.height_at(state.position+axle+side),kerbs.height_at(state.position-axle-side),kerbs.height_at(state.position-axle+side))


func slow_in_snow(state: VehicleState, previous: Vector2, config: HandlingConfig, seconds: float) -> void:
	snow_banks.slow_car(state,previous,config,seconds)
