class_name BridgeElevation
extends RefCounted
## Pure spatial elevation shared by client presentation and verified ghosts.
## Presentation only: no temporal easing and no changes to canonical handling.

const VERSION: String = "bridge-ramps-6"
const ROAD_HEIGHT = preload("res://track/road_surface_height.gd")
const APPROACH: float = 4.0
const INSET: float = 4.0
var track: NativeTrack
var roles := PackedInt32Array()
var upper_route := PackedByteArray()
var minimum: float = INF
var maximum: float = -INF
var inset: float = 0.0
var road_surface: RefCounted


func _init(data: NativeTrack) -> void:
	track = data
	road_surface = ROAD_HEIGHT.new(track)
	roles = track.deck_cells.duplicate()
	if track.metadata.has("legacy_deck"):
		roles.fill(-1)
		track._expand(track.metadata.legacy_deck,roles)
	var legacy_roles: PackedInt32Array = roles.duplicate()
	upper_route.resize(track.route.size())
	if track.bridge_height == 0.0:
		return
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			if roles[y * track.grid_width + x] < 0:
				continue
			for corner: Vector2 in [Vector2(x,y),Vector2(x+1,y),Vector2(x,y+1),Vector2(x+1,y+1)]:
				var along: float = point(corner).dot(track.bridge_axis)
				minimum = minf(minimum, along)
				maximum = maxf(maximum, along)
	inset = minf(INSET, (maximum - minimum) * 0.22)
	# Extend only the deck's longitudinal ends, preserving its transverse outline.
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			var index: int = y * track.grid_width + x
			if roles[index] >= 0:
				continue
			var p: Vector2 = point(Vector2(x+0.5,y+0.5))
			var u: float = p.dot(track.bridge_axis)
			if u < minimum - APPROACH or u > maximum + APPROACH or (u >= minimum + inset and u <= maximum - inset):
				continue
			var direction: Vector2 = track.bridge_axis * (1.0 if u < (minimum + maximum) * 0.5 else -1.0)
			for step: int in range(1, ceili(APPROACH / track.cell_size) + 2):
				var sample_point: Vector2 = p + direction * step * track.cell_size
				var cell: Vector2i = cell_for(sample_point)
				if inside(cell):
					var kind: int = legacy_roles[cell.y * track.grid_width + cell.x]
					if kind >= 0:
						# New approaches are road only. Keep rail geometry confined
						# to the existing canonical rail cells, where it collides.
						roles[index] = 0
						break
	# Extend each upper route branch far enough to cover its approaches. Local
	# progression, rather than heading, keeps the underpass at ground height.
	for i: int in range(track.route.size()):
		var route_cell: Vector2i = cell_for(track.route[i])
		if not inside(route_cell) or legacy_roles[route_cell.y*track.grid_width+route_cell.x] < 0: continue
		if not track.elevated_at(track.route[i], i):
			continue
		upper_route[i] = 1
		for direction: int in [-1,1]:
			var distance: float = 0.0
			var previous: int = i
			for offset: int in range(1, track.route.size()):
				var j: int = posmod(i + direction * offset, track.route.size())
				distance += track.route[previous].distance_to(track.route[j])
				if distance > APPROACH + 3.0:
					break
				upper_route[j] = 1
				previous = j


func point(cell: Vector2) -> Vector2:
	return Vector2(cell.x * track.cell_size - track.half_extent.x, track.half_extent.y - cell.y * track.cell_size)


func cell_for(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x + track.half_extent.x) / track.cell_size), floori((track.half_extent.y - p.y) / track.cell_size))


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < track.grid_width and cell.y < track.grid_height


func profile_height(p: Vector2) -> float:
	if track.bridge_height == 0.0:
		return 0.0
	var u: float = p.dot(track.bridge_axis)
	return track.bridge_height * minf(smoothstep(minimum - APPROACH, minimum + inset, u), 1.0 - smoothstep(maximum - inset, maximum + APPROACH, u))


func height_at(p: Vector2, route_index: int, actual_layer: int = -1) -> float:
	for span: Dictionary in track.creator_bridges:
		if CreatorBridges.contains(span,p):
			var elevated: bool = actual_layer == 1 if actual_layer >= 0 else track.elevated_at(p,route_index)
			return CreatorBridges.height(span,p)+road_surface.lift if elevated else road_surface.ground(p)
	if route_index < 0 or upper_route[route_index] == 0:
		return road_surface.ground(p)
	var cell: Vector2i = cell_for(p)
	if not inside(cell) or roles[cell.y * track.grid_width + cell.x] < 0:
		return road_surface.ground(p)
	return profile_height(p)+road_surface.lift
