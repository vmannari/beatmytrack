class_name NativeTrackVisual
extends Node3D
## Original matte track kit derived solely from native surface geometry.

const VERSION: String = "track-kit-3"
const COLORS: Array[Color] = TrackTheme.PINE # Legacy geometry-debug palette.
const TERRAIN_SHADER: Shader = preload("res://track/terrain.gdshader")
var theme_id: String = "pine"
var colors: Array[Color] = []
var scenic_count: int = 0


func build(track: NativeTrack, bridge: BridgePresentation) -> void:
	theme_id = TrackTheme.normalized(str(track.metadata.get("theme", "pine")))
	colors = TrackTheme.palette(theme_id)
	VisualGeometry.box(self, Vector3(1000, 0.1, 1000), Vector3(0, -0.15, 0), VisualGeometry.material(colors[1]))
	_build_terrain(track)
	_build_barriers(track)
	_build_low_cover(track)
	_build_placed_objects(track)
	bridge.build(self)
	_build_finish(track)


func _build_terrain(track: NativeTrack) -> void:
	var low := Image.create(track.grid_width, track.grid_height, false, Image.FORMAT_RGBA8)
	var high := Image.create(track.grid_width, track.grid_height, false, Image.FORMAT_RGBA8)
	low.fill(Color(0,0,0,0))
	high.fill(Color(0,0,0,0))
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			var kind: int = track.cells[y * track.grid_width + x]
			var weights := Color(0,0,0,0)
			weights[kind % 4] = 1.0
			if kind < 4: low.set_pixel(x, y, weights)
			else: high.set_pixel(x, y, weights)
	var surface := ShaderMaterial.new()
	surface.shader = TERRAIN_SHADER
	surface.set_shader_parameter("surface_low", ImageTexture.create_from_image(low))
	surface.set_shader_parameter("surface_high", ImageTexture.create_from_image(high))
	surface.set_shader_parameter("map_texel", Vector2(1.0 / track.grid_width, 1.0 / track.grid_height))
	for i: int in range(colors.size()): surface.set_shader_parameter("color_" + str(i), colors[i])
	var plane := PlaneMesh.new()
	plane.size = track.half_extent * 2.0
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = surface
	# The flat coverage sheet must not cast a rectangular map-border shadow.
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_barriers(track: NativeTrack) -> void:
	var cap := SurfaceTool.new()
	var sides := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	# Merged top faces and exposed perimeter only: no interior wall seams.
	for r: Array in track.rectangles:
		if int(r[4]) != 4:
			continue
		var x: float = float(r[0]) * track.cell_size - track.half_extent.x
		var z: float = float(r[1]) * track.cell_size - track.half_extent.y
		var w: float = float(r[2]) * track.cell_size
		var h: float = float(r[3]) * track.cell_size
		_quad(cap, Vector3(x, 0.65, z), Vector3(x+w, 0.65, z), Vector3(x+w, 0.65, z+h), Vector3(x, 0.65, z+h))
		count += 1
	for y: int in range(track.grid_height):
		for x: int in range(track.grid_width):
			if track.cells[y * track.grid_width + x] != 4:
				continue
			var a := Vector3(x * track.cell_size - track.half_extent.x, 0.65, y * track.cell_size - track.half_extent.y)
			var corners: Array[Vector3] = [a, a+Vector3.RIGHT*track.cell_size, a+Vector3(1,0,1)*track.cell_size, a+Vector3.BACK*track.cell_size]
			var neighbors: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
			for edge: int in range(4):
				var n: Vector2i = Vector2i(x,y) + neighbors[edge]
				if n.x >= 0 and n.y >= 0 and n.x < track.grid_width and n.y < track.grid_height and track.cells[n.y * track.grid_width + n.x] == 4:
					continue
				var p: Vector3 = corners[edge]
				var q: Vector3 = corners[(edge+1)%4]
				_quad(sides, p, q, q-Vector3.UP*0.65, p-Vector3.UP*0.65)
	if count:
		_commit(cap, colors[4].lightened(0.17))
		_commit(sides, colors[4].darkened(0.16))


func _build_low_cover(track: NativeTrack) -> void:
	var scenery := SurfaceTool.new()
	scenery.begin(Mesh.PRIMITIVE_TRIANGLES)
	var foliage: Color = TrackTheme.foliage(theme_id)
	var stone: Color = TrackTheme.stone(theme_id)
	# A world-space lattice with bounded offsets gives reproducible scenery,
	# without per-frame work or an RNG dependency in canonical track data.
	# Baked vertex colors reduce the entire prop kit to one mesh/material.
	var stride: int = maxi(1, ceili(3.7 / track.cell_size))
	for y: int in range(stride, track.grid_height - stride, stride):
		for x: int in range(stride, track.grid_width - stride, stride):
			var kind: int = track.cells[y * track.grid_width + x]
			var seed_value: int = (x * 73856093 ^ y * 19349663) & 0x7fffffff
			if kind not in [1, 7] or seed_value % 3 == 0 or scenic_count >= 180:
				continue
			var cell := Vector2i(x + (seed_value % 5) - 2, y + ((seed_value / 7) % 5) - 2)
			if not _cover_clear(track, cell, 1.3):
				continue
			var center := Vector3((cell.x+0.5)*track.cell_size-track.half_extent.x, 0.014, (cell.y+0.5)*track.cell_size-track.half_extent.y)
			var scale_value: float = 0.8 + (seed_value % 11) * 0.035
			var turn: float = (seed_value % 37) * 0.17
			if theme_id == "pine" and seed_value % 3 == 1 and _cover_clear(track, cell, 4.4):
				# Mature narrow pines, safely beyond their projected road envelope.
				_pine(scenery, center, scale_value, turn, foliage)
			else:
				var color: Color = stone if seed_value % 4 == 0 else foliage
				var height: float = 0.34 if seed_value % 4 == 0 else 0.58
				_mound(scenery, center, Vector3(0.67, height, 0.48) * scale_value, turn, color)
				_mound(scenery, center + Vector3(0.5, 0, 0.25), Vector3(0.42, height * 0.6, 0.35), turn+1.2, color.darkened(0.08))
			scenic_count += 1
	if scenic_count:
		scenery.generate_normals()
		var instance := MeshInstance3D.new()
		instance.mesh = scenery.commit()
		var material := VisualGeometry.material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		instance.material_override = material
		add_child(instance)


func _cover_clear(track: NativeTrack, cell: Vector2i, radius: float) -> bool:
	var point := Vector2((cell.x+0.5)*track.cell_size-track.half_extent.x,track.half_extent.y-(cell.y+0.5)*track.cell_size)
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[]):
		if point.distance_to(Vector2(object.position[0],object.position[1])) < radius+3.0: return false
	# Check the whole square footprint, including bridges. A tree must never
	# hide a corner, gate, ramp or native barrier. Low cover remains passable.
	var extent: int = ceili(radius / track.cell_size)
	if cell.x < extent or cell.y < extent or cell.x + extent >= track.grid_width or cell.y + extent >= track.grid_height:
		return false
	for y: int in range(cell.y - extent, cell.y + extent + 1):
		for x: int in range(cell.x - extent, cell.x + extent + 1):
			var index: int = y * track.grid_width + x
			if track.cells[index] not in [1, 7] or track.deck_cells[index] >= 0:
				return false
	return true


func _build_placed_objects(track: NativeTrack) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = 0
	for object: Dictionary in track.metadata.get("creator_document",{}).get("objects",[]):
		var center := Vector3(float(object.position[0]),0.014,-float(object.position[1]))
		if object.kind == "tree":
			_pine(tool,center,0.65,-deg_to_rad(float(object.rotation)),TrackTheme.foliage(theme_id))
		elif object.kind == "rock":
			_mound(tool,center,Vector3(0.95,0.5,0.9),-deg_to_rad(float(object.rotation)),TrackTheme.stone(theme_id))
		else: continue # Barrier/water/dirt already rendered from exact native cells.
		count += 1
	if count > 0:
		tool.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = tool.commit()
		var material := VisualGeometry.material(Color.WHITE)
		material.vertex_color_use_as_albedo = true
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material
		add_child(mesh)


func _mound(tool: SurfaceTool, center: Vector3, dimensions: Vector3, turn: float, color: Color) -> void:
	# Two irregular bevel rings create broad stone / scrub planes, no spheres.
	var lower := PackedVector3Array()
	var upper := PackedVector3Array()
	for i: int in range(7):
		var angle: float = turn + TAU * i / 7.0
		var radial := Vector3(cos(angle) * dimensions.x, 0, sin(angle) * dimensions.z)
		lower.append(center + radial * (0.91 + (i%3)*0.06))
		upper.append(center + radial * 0.57 + Vector3(0.06, dimensions.y * (0.7+(i%2)*0.14), 0.03))
	var top: Vector3 = center + Vector3(0.1, dimensions.y, -0.03)
	for i: int in range(7):
		var j: int = (i+1)%7
		tool.set_color(color.darkened(0.08 if i%3 == 0 else 0.0))
		_quad(tool, lower[i], lower[j], upper[j], upper[i])
		tool.set_color(color.lightened(0.045))
		for v: Vector3 in [upper[i], top, upper[j]]: tool.add_vertex(v)


func _pine(tool: SurfaceTool, center: Vector3, scale_value: float, turn: float, color: Color) -> void:
	_mound(tool, center, Vector3(0.12, 1.25, 0.12) * scale_value, turn, Color("554e40"))
	for tier: int in range(3):
		var base: Vector3 = center + Vector3(0.07*tier, 0.65 + tier*0.74, 0.03*tier)*scale_value
		var radius: float = (1.1 - tier*0.23) * scale_value
		var tip: Vector3 = base + Vector3(-0.12, 1.55 - tier*0.1, 0.05)*scale_value
		for i: int in range(7):
			var a: float = turn + TAU*i/7.0
			var b: float = turn + TAU*(i+1)/7.0
			var p: Vector3 = base + Vector3(cos(a), 0.07*(i%2), sin(a))*radius
			var q: Vector3 = base + Vector3(cos(b), 0.07*((i+1)%2), sin(b))*radius
			tool.set_color(color.lightened(tier*0.035).darkened(0.07 if i%3 == 0 else 0.0))
			for v: Vector3 in [p, tip, q]: tool.add_vertex(v)
			tool.set_color(color.darkened(0.22))
			for v: Vector3 in [p, q, base]: tool.add_vertex(v)


func _build_finish(track: NativeTrack) -> void:
	var side := Vector2(track.finish_forward.y, -track.finish_forward.x)
	var light := SurfaceTool.new()
	var dark := SurfaceTool.new()
	light.begin(Mesh.PRIMITIVE_TRIANGLES)
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var counts: Array[int] = [0, 0]
	var size: float = 0.5
	# Paint the local finish road, not every disconnected lane intersected by
	# the deliberately broad practice gate. Gate timing data stays unchanged.
	var road_kind: int = track.cell_at(track.finish_center)
	var widths := Vector2.ZERO
	for direction: int in [-1,1]:
		for step: int in range(1, ceili(track.finish_half_width / track.cell_size) + 1):
			var distance: float = step * track.cell_size
			if track.cell_at(track.finish_center + side * distance * direction) != road_kind:
				break
			widths[0 if direction < 0 else 1] = distance
	for row: int in range(2):
		for i: int in range(ceili(track.finish_half_width * 2 / size)):
			var offset: float = -track.finish_half_width + (i + 0.5) * size
			if offset - size * 0.5 < -widths.x or offset + size * 0.5 > widths.y:
				continue
			var point: Vector2 = track.finish_center + side * offset + track.finish_forward * (row - 0.5) * size
			if track.cell_at(point) not in [0, 2, 5, 6]:
				continue
			var center: Vector3 = VisualGeometry.world(point) + Vector3.UP * 0.024
			var across: Vector3 = VisualGeometry.world(side) * size * 0.5
			var along: Vector3 = VisualGeometry.world(track.finish_forward) * size * 0.5
			var parity: int = (row+i)%2
			_quad(light if parity == 0 else dark, center-across-along, center+across-along, center+across+along, center-across+along)
			counts[parity] += 1
	if counts[0]: _commit(light, Color("d4d5c5"))
	if counts[1]: _commit(dark, Color("252f32"))


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v: Vector3 in [a,c,b,a,d,c]: tool.add_vertex(v)


func _commit(tool: SurfaceTool, color: Color) -> void:
	tool.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = tool.commit()
	var material := VisualGeometry.material(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	instance.material_override = material
	add_child(instance)
