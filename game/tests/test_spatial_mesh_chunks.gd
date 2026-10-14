extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: "+label)
func signature(mesh: Mesh) -> Array[String]:
	var result: Array[String] = []
	var arrays: Array = mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count: int = indices.size() if not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
	for start: int in range(0,count,3):
		var values: Array = []
		for corner: int in range(3):
			var index: int = indices[start+corner] if not indices.is_empty() else start+corner
			for attribute: int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2,Mesh.ARRAY_COLOR]:
				if arrays[attribute] != null: values.append(arrays[attribute][index])
		result.append(var_to_bytes(values).hex_encode())
	result.sort()
	return result
func run() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle: int in range(8192):
		var center := Vector3((triangle%32-16)*4.0,0,(triangle/32-128)*1.0)
		tool.set_normal(Vector3.UP)
		for corner: int in range(3):
			tool.set_color(Color((triangle%19)/19.0,(triangle%23)/23.0,0.5,1))
			tool.set_uv(Vector2(triangle/8192.0,corner/2.0))
			tool.set_uv2(Vector2(corner/2.0,triangle/8192.0))
			tool.add_vertex(center+Vector3([0,0.8,0.0][corner],0,[0,0,0.6][corner]))
	tool.index()
	var mesh: ArrayMesh = tool.commit()
	var expected: Array[String] = signature(mesh)
	var source := MeshInstance3D.new()
	source.name = "StaticFixture"
	source.mesh = mesh
	source.material_override = VisualGeometry.material(Color.WHITE)
	source.layers = 2
	source.transform = Transform3D(Basis(Vector3.UP,0.3),Vector3(7,2,-13))
	var original_transform: Transform3D = source.transform
	var material: Material = source.material_override
	var parts: Array[MeshInstance3D] = SpatialMeshChunks.add(parent,source,true,false,false)
	check(parts.size() > 1 and parts.size() <= SpatialMeshChunks.MAX_CHUNKS,"bounded spatial draw nodes")
	var actual: Array[String] = []
	for part: MeshInstance3D in parts:
		actual.append_array(signature(part.mesh))
		check(part.transform == original_transform and part.layers == 2 and part.material_override == material,"unchanged transform/layers/material")
	actual.sort()
	check(actual == expected,"every indexed position/normal/UV/UV2/pigment triangle retained exactly")
	print("SPATIAL_MESH_CHUNKS ",checks," checks, ",failures," failures, nodes=",parts.size())
	quit(1 if failures else 0)
