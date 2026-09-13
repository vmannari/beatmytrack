class_name BridgePresentation
extends RefCounted
## Spatial road elevation shared by bridge meshes and vehicle presentation.
## Presentation only: no temporal easing and no changes to canonical handling.

const VERSION: String = "bridge-ramps-1"
const APPROACH: float = 4.0
const INSET: float = 4.0
var track: NativeTrack
var roles := PackedInt32Array()
var upper_route := PackedByteArray()
var minimum: float = INF
var maximum: float = -INF
var inset: float = 0.0


func _init(data: NativeTrack) -> void:
	track = data
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
			return CreatorBridges.height(span,p) if elevated else 0.0
	if route_index < 0 or upper_route[route_index] == 0:
		return 0.0
	var cell: Vector2i = cell_for(p)
	if not inside(cell) or roles[cell.y * track.grid_width + cell.x] < 0:
		return 0.0
	return profile_height(p)


func build(parent: Node3D) -> void:
	CreatorBridgeVisual.build(parent,track.creator_bridges)
	var palette: Array[Color] = TrackTheme.palette(str(track.metadata.get("theme", "pine")))
	for kind: int in [0,4]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count: int = 0
		for y: int in range(track.grid_height):
			for x: int in range(track.grid_width):
				if roles[y * track.grid_width + x] != kind:
					continue
				var vertices: Array[Vector3] = []
				for corner: Vector2 in [Vector2(x,y),Vector2(x+1,y),Vector2(x+1,y+1),Vector2(x,y+1)]:
					var p: Vector2 = point(corner)
					vertices.append(VisualGeometry.world(p) + Vector3.UP * (profile_height(p) + (0.65 if kind == 4 else 0.015)))
				for i: int in [0,2,1,0,3,2]: surface.add_vertex(vertices[i])
				if kind == 4:
					for i: int in range(4):
						var neighbor: Vector2i = Vector2i(x,y) + [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][i]
						if inside(neighbor) and roles[neighbor.y * track.grid_width + neighbor.x] == kind:
							continue
						var a: Vector3 = vertices[i]
						var b: Vector3 = vertices[(i+1)%4]
						for v: Vector3 in [a,b,b-Vector3.UP*0.65,a,b-Vector3.UP*0.65,a-Vector3.UP*0.65]: surface.add_vertex(v)
				count += 1
		if count:
			surface.generate_normals()
			var mesh := MeshInstance3D.new()
			mesh.mesh = surface.commit()
			var material := VisualGeometry.material(palette[4].lightened(0.17) if kind == 4 else palette[0].lightened(0.06))
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.material_override = material
			parent.add_child(mesh)
