class_name NativeTrack
extends PlaygroundData
## Native SI surface geometry. No knowledge of SS blocks, palettes or file layout.

var cell_size: float
var grid_width: int
var grid_height: int
var cells := PackedInt32Array()
var deck_cells := PackedInt32Array()
var rectangles: Array
var deck_rectangles: Array
var route := PackedVector2Array()
var checkpoints: Array[Rect2] = []
var bridge_axis := Vector2.ZERO
var bridge_height: float = 0.0
var metadata: Dictionary
var content_hash: String
var finish_center := Vector2.ZERO
var finish_forward := Vector2.ZERO
var finish_half_width: float = 0.0


static func read(path: String) -> NativeTrack:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("schema", "") not in ["surface-grid-v1", "surface-grid-v2"]:
		push_error("Invalid native track: " + path)
		return null
	var track := NativeTrack.new()
	track.metadata = data
	track.content_hash = FileAccess.get_sha256(path)
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
	for r: Array in data.checkpoints:
		track.checkpoints.append(Rect2(r[0], r[1], r[2], r[3]))
	if not data.bridges.is_empty():
		track.bridge_axis = Vector2(data.bridges[0].axis[0], data.bridges[0].axis[1])
		track.bridge_height = float(data.bridges[0].height)
	return track


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
	if bridge_height == 0.0:
		return false
	var tangent: Vector2 = (route[(route_index + 1) % route.size()] - route[route_index]).normalized()
	var x: int = floori((point.x + half_extent.x) / cell_size)
	var y: int = floori((half_extent.y - point.y) / cell_size)
	return x >= 0 and y >= 0 and x < grid_width and y < grid_height and deck_cells[y * grid_width + x] >= 0 and absf(tangent.dot(bridge_axis)) > 0.75


func surface_factors(state: VehicleState) -> Vector2:
	var speed: float = state.velocity.length()
	match cell_at(state.position, state.track_elevated):
		1: return Vector2(0.65, 2.0 + speed * 0.65)
		2: return Vector2(0.8, 2.0)
		5: return Vector2(0.95, 0.4)
		6: return Vector2(0.7, 3.0)
		7: return Vector2(0.65, 2.0 + speed * 0.9) # Slows even under power, but allows escape from rest.
	return Vector2(1.0, 0.0)


func resolve(state: VehicleState, from: Vector2, config: HandlingConfig) -> void:
	state.route_index = nearest_route(from, state.route_index)
	state.track_elevated = elevated_at(from, state.route_index)
	# Circle against native occupied cells, substeps shorter than half a cell.
	# Stable row order and bounded path sampling prevent thin-wall tunnelling.
	var movement: Vector2 = state.position - from
	var steps: int = maxi(1, ceili(movement.length() / (cell_size * 0.45)))
	var accepted: Vector2 = from
	var contact: Vector3 = _contact(from, config.collision_radius, state.track_elevated)
	for step_index: int in range(1, steps + 1):
		var point: Vector2 = from + movement * (float(step_index) / steps)
		var next_route: int = nearest_route(point, state.route_index)
		var next_elevated: bool = elevated_at(point, next_route)
		var next_contact: Vector3 = _contact(point, config.collision_radius, next_elevated)
		if next_contact.z > 0.0:
			# A pre-existing overlap must not freeze outward movement. Require
			# strictly decreasing overlap on the same layer, at every substep.
			# New contacts/layer changes still stop at the last accepted position.
			var escaping: bool = next_elevated == state.track_elevated and contact.z > 0.0 and next_contact.z < contact.z
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
					var candidate_layer: bool = elevated_at(candidate, candidate_route)
					if candidate_layer != state.track_elevated or _contact(candidate, config.collision_radius, candidate_layer).z > 0.0:
						break
					state.position = candidate
					state.route_index = candidate_route
				return
		accepted = point
		contact = next_contact
		state.route_index = next_route
		state.track_elevated = next_elevated
	state.position = accepted


func collision_normal(point: Vector2, radius: float, elevated: bool) -> Vector2:
	var contact: Vector3 = _contact(point, radius, elevated)
	return Vector2(contact.x, contact.y)


func _escape_blocker(from: Vector2, point: Vector2, radius: float, elevated: bool) -> Vector2:
	# Reducing total overlap must not hide entry into another cell/barrier.
	# Every affected cell must keep or reduce its own penetration (1 um tolerance).
	var cx: int = floori((point.x + half_extent.x) / cell_size)
	var cy: int = floori((half_extent.y - point.y) / cell_size)
	var reach: int = ceili(radius / cell_size) + 1
	for y: int in range(cy - reach, cy + reach + 1):
		for x: int in range(cx - reach, cx + reach + 1):
			var center := Vector2((x + 0.5) * cell_size - half_extent.x, half_extent.y - (y + 0.5) * cell_size)
			if cell_at(center, elevated) not in [3,4]: continue
			var low: Vector2 = center - Vector2.ONE * cell_size * 0.5
			var high: Vector2 = center + Vector2.ONE * cell_size * 0.5
			var offset: Vector2 = point - point.clamp(low, high)
			var before: float = maxf(0.0, radius - from.distance_to(from.clamp(low, high)))
			var after: float = maxf(0.0, radius - offset.length())
			if after > before + 0.000001:
				return offset.normalized() if offset != Vector2.ZERO else (from - center).normalized()
	return Vector2.ZERO


func _contact(point: Vector2, radius: float, elevated: bool) -> Vector3:
	# XY is the outward normal; Z is summed squared cell penetration. The latter
	# stays positive even where opposing cell normals cancel (inside a solid).
	var cx: int = floori((point.x + half_extent.x) / cell_size)
	var cy: int = floori((half_extent.y - point.y) / cell_size)
	var reach: int = ceili(radius / cell_size) + 1
	var total := Vector2.ZERO
	var overlap: float = 0.0
	var fallback := Vector2.RIGHT
	for y: int in range(cy - reach, cy + reach + 1):
		for x: int in range(cx - reach, cx + reach + 1):
			var center := Vector2((x + 0.5) * cell_size - half_extent.x, half_extent.y - (y + 0.5) * cell_size)
			if cell_at(center, elevated) not in [3, 4]:
				continue
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
