extends RefCounted
func props_fixture(theme_id: String) -> NativeTrack:
	var objects: Array = []
	for family: Array in CreatorCatalog.ASSETS:
		for kind: String in family[3]:
			var index: int = objects.size()
			var object: Dictionary = {"kind":kind,"position":[-48.0+(index%10)*10.0,-25.0+(index/10)*13.0],"rotation":float((index*37)%360)}
			if kind not in ["tyre_stack","tyre_wall"]: object.scale = 0.75 if index%2 else 1.25
			if kind in ObjectRuns.CONTINUOUS: object.length = 3.25
			if kind == "container": object.color = "c05a38"
			if kind == "speed_bump": object.span = 8.25
			objects.append(object)
	# Shared endpoints, intersections and coincident paint variants exercise
	# the original normal generation and opaque ordering between objects.
	objects.append_array([
		{"kind":"barrier","position":[-15.0,25.0],"rotation":0.0,"length":6.0},
		{"kind":"barrier","position":[-9.0,25.0],"rotation":0.0,"length":6.0},
		{"kind":"container","position":[15.0,25.0],"rotation":0.0,"color":"ad894f"},
		{"kind":"container","position":[15.0,25.0],"rotation":0.0,"color":"c05a38"},
		{"kind":"guardrail","position":[38.0,25.0],"rotation":0.0,"length":6.0},
		{"kind":"guardrail","position":[38.0,25.0],"rotation":90.0,"length":6.0}
	])
	var track := NativeTrack.new()
	track.metadata = {"theme":theme_id,"creator_document":{"objects":objects},"scenery_objects":[]}
	track.tyre_origins = LooseTyres.positions(track.metadata.creator_document)
	return track

func triangles(node: Node3D, parent_pose: Transform3D = Transform3D.IDENTITY) -> Dictionary:
	var result: Dictionary = {}
	if node.is_in_group("contact_lighting"): return result
	var pose: Transform3D = parent_pose*node.transform
	var mesh: Mesh
	var transforms: Array[Transform3D] = []
	if node is MeshInstance3D and node.visible:
		mesh = node.mesh; transforms.append(pose)
	elif node is MultiMeshInstance3D and node.visible:
		mesh = node.multimesh.mesh
		for index: int in range(node.multimesh.instance_count): transforms.append(pose*node.multimesh.get_instance_transform(index))
	if mesh != null:
		for surface: int in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var pigments: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var count: int = indices.size() if not indices.is_empty() else vertices.size()
			for transform: Transform3D in transforms:
				for offset: int in range(0,count,3):
					var corners: Array = []
					for corner: int in range(3):
						var index: int = indices[offset+corner] if not indices.is_empty() else offset+corner
						var p: Vector3 = transform*vertices[index]
						var n: Vector3 = (transform.basis*normals[index]).normalized()
						var pigment: Color = pigments[index] if not pigments.is_empty() else Color.WHITE
						corners.append({"p":p,"n":n,"color":pigment,"key":str(p.snapped(Vector3.ONE*0.001))+"/"+str(pigment)})
					corners.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.key < b.key)
					var keys: Array[String] = []
					for corner: Dictionary in corners: keys.append(corner.key)
					var key: String = "|".join(keys)
					if not result.has(key): result[key] = []
					result[key].append(corners)
	for child: Node in node.get_children():
		if not child is Node3D or not child.visible: continue
		var sub: Dictionary = triangles(child,pose)
		for key: String in sub:
			if not result.has(key): result[key] = []
			result[key].append_array(sub[key])
	return result

func same_triangles(before: Dictionary, after: Dictionary) -> bool:
	if before.size() != after.size(): return false
	var maximum_position: float = 0.0
	var maximum_normal: float = 0.0
	for key: String in before:
		if not after.has(key) or before[key].size() != after[key].size(): return false
		var candidates: Array = after[key].duplicate()
		for triangle: Array in before[key]:
			var match_index: int = -1
			for index: int in range(candidates.size()):
				var matches: bool = true
				for corner: int in range(3):
					var p: float = Vector3(triangle[corner].p).distance_to(candidates[index][corner].p)
					var n: float = Vector3(triangle[corner].n).distance_to(candidates[index][corner].n)
					matches = matches and p == 0.0 and n == 0.0 and triangle[corner].color == candidates[index][corner].color
					maximum_position = maxf(maximum_position,p); maximum_normal = maxf(maximum_normal,n)
				if matches: match_index = index; break
			if match_index < 0: return false
			candidates.remove_at(match_index)
	print("EDITOR_TRIANGLE_TOLERANCE maximum_position_m=",maximum_position," maximum_normal_distance=",maximum_normal)
	return true
