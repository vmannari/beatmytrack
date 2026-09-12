class_name NativeTrackVisual
extends Node3D
## Original matte track kit derived solely from native surface geometry.

const VERSION: String = "track-kit-2"
const COLORS: Array[Color] = [Color("394447"), Color("465b3e"), Color("89765b"), Color("375c64"), Color("767f77"), Color("b5b4a4"), Color("52757a"), Color("756c59")]
const TERRAIN_SHADER: Shader = preload("res://track/terrain.gdshader")


func build(track: NativeTrack, bridge: BridgePresentation) -> void:
	VisualGeometry.box(self, Vector3(1000, 0.1, 1000), Vector3(0, -0.15, 0), VisualGeometry.material(COLORS[1]))
	_build_terrain(track)
	_build_barriers(track)
	_build_low_cover(track)
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
	for i: int in range(COLORS.size()): surface.set_shader_parameter("color_" + str(i), COLORS[i])
	var plane := PlaneMesh.new()
	plane.size = track.half_extent * 2.0
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = surface
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
		_commit(cap, Color("9b9f94"))
		_commit(sides, Color("626e67"))


func _build_low_cover(track: NativeTrack) -> void:
	var grass := SurfaceTool.new()
	var gravel := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	gravel.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_count: int = 0
	var gravel_count: int = 0
	# Sparse low tufts and gravel stay below the car and reveal the driving line.
	for y: int in range(2, track.grid_height - 2, 3):
		for x: int in range(2, track.grid_width - 2, 3):
			var kind: int = track.cells[y * track.grid_width + x]
			var seed_value: int = (x * 73856093 ^ y * 19349663) & 0x7fffffff
			if kind not in [1, 7] or seed_value % 5 != 0:
				continue
			if track.cells[y * track.grid_width + x-1] != kind or track.cells[y * track.grid_width + x+1] != kind:
				continue
			var center := Vector3((x+0.5)*track.cell_size-track.half_extent.x, 0.012, (y+0.5)*track.cell_size-track.half_extent.y)
			var tool: SurfaceTool = grass if kind == 1 else gravel
			var radius: float = 0.13 if kind == 1 else 0.10
			var tip: Vector3 = center + Vector3(0.04, 0.16 if kind == 1 else 0.055, 0.02)
			for i: int in range(5):
				var angle: float = TAU * i / 5.0
				var next_angle: float = TAU * (i+1) / 5.0
				for v: Vector3 in [center+Vector3(cos(angle),0,sin(angle))*radius, tip, center+Vector3(cos(next_angle),0,sin(next_angle))*radius]:
					tool.add_vertex(v)
			if kind == 1: grass_count += 1
			else: gravel_count += 1
	if grass_count: _commit(grass, Color("536847"))
	if gravel_count: _commit(gravel, Color("9b9078"))


func _build_finish(track: NativeTrack) -> void:
	var side := Vector2(track.finish_forward.y, -track.finish_forward.x)
	var light := VisualGeometry.material(Color("d4d5c5"))
	var dark := VisualGeometry.material(Color("252f32"))
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
			var tile := VisualGeometry.box(self, Vector3(size, 0.015, size), VisualGeometry.world(point) + Vector3.UP * 0.016, light if (row+i)%2 == 0 else dark)
			tile.rotation.y = -atan2(track.finish_forward.x, track.finish_forward.y)


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
