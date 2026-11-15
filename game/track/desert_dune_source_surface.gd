extends RefCounted
## Conservative projection of banks that replace the world-space dune artwork.
## Coalescing occupied cells avoids retaining every relief-subdivision triangle.
const MAX_CELLS: int = 65536
var cell_size: float = 1.0
var cells: Dictionary = {}
var conservative: Array[Rect2] = []
var input_triangles: int = 0

func prepare(visual: Node3D) -> void:
	for node: Node in visual.get_children():
		if not node is MeshInstance3D or node.mesh == null: continue
		var material: ShaderMaterial = node.material_override as ShaderMaterial
		if material == null or material.get_shader_parameter("gravel") != true: continue
		var transform: Transform3D = visual.transform * node.transform
		for surface: int in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			input_triangles += count / 3
			for corner: int in range(0, count, 3):
				if uv.is_empty() or uv[indices[corner] if not indices.is_empty() else corner].x >= -0.5: continue
				var area := Rect2()
				for offset: int in range(3):
					var at: Vector3 = transform * vertices[indices[corner + offset] if not indices.is_empty() else corner + offset]
					var point := Vector2(at.x, -at.z)
					area = Rect2(point, Vector2.ZERO) if offset == 0 else area.expand(point)
				mark(area)

func mark(area: Rect2) -> void:
	var first := Vector2i((area.position / cell_size).floor())
	var last := Vector2i((area.end / cell_size).floor())
	if (last.x - first.x + 1) * (last.y - first.y + 1) > 256:
		conservative.append(area.grow(0.01))
		return
	if cells.size() + 256 > MAX_CELLS:
		var coarser: Dictionary = {}
		for key: Vector2i in cells: coarser[Vector2i((Vector2(key) / 2.0).floor())] = true
		cells = coarser; cell_size *= 2.0
		mark(area)
		return
	for y: int in range(first.y, last.y + 1):
		for x: int in range(first.x, last.x + 1): cells[Vector2i(x, y)] = true

func clear(point: Vector2) -> bool:
	if cells.has(Vector2i((point / cell_size).floor())): return false
	for area: Rect2 in conservative:
		if area.has_point(point): return false
	return true
