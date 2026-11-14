extends RefCounted
## Pixel-integrated flush contours. Positions and centre lines remain exact.
const SHADER = preload("res://vehicle/panel_contour.gdshader")
static var meshes: Dictionary = {}
static var materials: Dictionary = {}

static func material(source: StandardMaterial3D) -> ShaderMaterial:
	var color: Color = source.albedo_color
	if not materials.has(color):
		if materials.size() >= 16: materials.clear()
		var result := ShaderMaterial.new()
		result.shader = SHADER
		result.set_shader_parameter("contour_color", color)
		materials[color] = result
	return materials[color]

static func mesh(source: ArrayMesh) -> ArrayMesh:
	if source.has_meta("pixel_integrated_contour"): return source
	if meshes.has(source): return meshes[source]
	if meshes.size() >= 128: meshes.clear()
	var result := ArrayMesh.new()
	for surface: int in range(source.get_surface_count()):
		var arrays: Array = source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(vertices.size())
			for i: int in range(vertices.size()): indices[i] = i
		# Imported strips can duplicate a position for corner normals. Weld only
		# the topology lookup; the actual render buffers keep those normals.
		var canonical := PackedInt32Array()
		canonical.resize(vertices.size())
		var positions: Dictionary = {}
		for i: int in range(vertices.size()):
			var p: Vector3 = vertices[i].snapped(Vector3.ONE*0.000001)
			if not positions.has(p): positions[p] = i
			canonical[i] = positions[p]
		var edge_counts: Dictionary = {}
		for offset: int in range(0,indices.size(),3):
			for corner: int in range(3):
				var a: int = canonical[indices[offset+corner]]
				var b: int = canonical[indices[offset+(corner+1)%3]]
				var edge := Vector2i(mini(a,b),maxi(a,b))
				edge_counts[edge] = int(edge_counts.get(edge,0))+1
		var partner := PackedInt32Array()
		partner.resize(vertices.size()); partner.fill(-1)
		var distance := PackedFloat64Array()
		distance.resize(vertices.size()); distance.fill(INF)
		for edge: Vector2i in edge_counts:
			# In a closed ribbon the one-face edges run along its boundaries.
			# Paired edges and diagonals are internal; the pair is the shorter.
			if int(edge_counts[edge]) != 2: continue
			var a: int = edge.x; var b: int = edge.y
			var squared: float = vertices[a].distance_squared_to(vertices[b])
			if squared < 1e-14: continue
			if squared < distance[a]: distance[a] = squared; partner[a] = b
			if squared < distance[b]: distance[b] = squared; partner[b] = a
		var pairs: Dictionary = {}
		var member := PackedInt32Array()
		member.resize(vertices.size()); member.fill(-1)
		for a: int in range(vertices.size()):
			var original: int = canonical[a]
			var b: int = partner[original]
			assert(b >= 0 and partner[b] == original, "Contour topology requires paired ribbon edges")
			var key: int = mini(original, b)
			member[a] = key
			if not pairs.has(key): pairs[key] = {"a":key,"b":maxi(original,b),"neighbors":[],"sign":0.0}
		for offset: int in range(0, indices.size(), 3):
			for corner: int in range(3):
				var a: int = member[indices[offset + corner]]
				var b: int = member[indices[offset + (corner + 1) % 3]]
				if a != b and b not in pairs[a].neighbors: pairs[a].neighbors.append(b)
		for start: int in pairs:
			if pairs[start].sign != 0.0: continue
			pairs[start].sign = 1.0
			var queue: Array[int] = [start]
			var cursor: int = 0
			while cursor < queue.size():
				var a: Dictionary = pairs[queue[cursor]]; cursor += 1
				var direction: Vector3 = (vertices[a.b] - vertices[a.a]) * float(a.sign)
				for next: int in a.neighbors:
					var b: Dictionary = pairs[next]
					if b.sign != 0.0: continue
					b.sign = 1.0 if direction.dot(vertices[b.b] - vertices[b.a]) >= 0.0 else -1.0
					queue.append(next)
		var uv := PackedVector2Array()
		uv.resize(vertices.size())
		var tangents := PackedFloat32Array()
		tangents.resize(vertices.size() * 4)
		for i: int in range(vertices.size()):
			var half: Vector3 = (vertices[i] - vertices[partner[canonical[i]]]) * 0.5
			var direction: Vector3 = half.normalized()
			var pair: Dictionary = pairs[member[i]]
			uv[i] = Vector2(float(pair.sign) * (-1.0 if canonical[i] == pair.a else 1.0), half.length())
			for axis: int in range(3): tangents[i * 4 + axis] = direction[axis]
			tangents[i * 4 + 3] = 1.0
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TANGENT] = tangents
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	result.set_meta("pixel_integrated_contour", true)
	meshes[source] = result
	return result
