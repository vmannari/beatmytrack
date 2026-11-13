extends SceneTree
## KSF01-KSF03: sewn shoulder topology, retained lower body and all steering poses.
const OUT = "res://../docs/evidence/kart-driver-shoulder-fit-2026-11-12"
const PATH = "res://assets/vehicles/kart_refined_v1/tomkart_driver_v1/"
var checks: int = 0
var failures: int = 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("SHOULDER_FIT_FAIL ",label)
func _initialize() -> void:
	var old: ArrayMesh = load(OUT+"/before/game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res")
	var mesh: ArrayMesh = load(PATH+"driver.res")
	var helmet: ArrayMesh = load(PATH+"helmet_static.res")
	check(mesh.get_surface_count()==2 and helmet.get_surface_count()==4,"moving cloth and static helmet roles retained")
	check(mesh.get_blend_shape_count()==6 and helmet.get_blend_shape_count()==0,"six steering poses without redundant head morphs")
	for surface: int in range(4):
		check(helmet.surface_get_arrays(surface)==old.surface_get_arrays(surface+2),"helmet geometry and finish unchanged")
	check(mesh.surface_get_arrays(0)==old.surface_get_arrays(0),"gloves unchanged")
	check(mesh.surface_get_blend_shape_arrays(0)==old.surface_get_blend_shape_arrays(0),"all six glove poses unchanged")
	var geometry: ArrayMesh = old if "--before" in OS.get_cmdline_user_args() else mesh
	var arrays: Array = geometry.surface_get_arrays(1)
	var before: Array = old.surface_get_arrays(1)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var prefix: int = mesh.get_meta("kart_suit_static_vertices")
	var protected: bool = true
	for vertex: int in range(prefix):
		if before[Mesh.ARRAY_VERTEX][vertex].y < 0.60 or before[Mesh.ARRAY_VERTEX][vertex].z > 0.41: protected = protected and points[vertex]==before[Mesh.ARRAY_VERTEX][vertex]
	check(protected,"lower torso, backrest, legs, boots and centre seam fitted positions retained")
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var joint_start: int = prefix+2*21*17
	var edges: Dictionary = {}
	var connected: int = 0
	for corner: int in range(0,indices.size(),3):
		for side: int in range(3):
			var a: int = indices[corner+side]
			var b: int = indices[corner+(side+1)%3]
			var key := Vector2i(mini(a,b),maxi(a,b))
			if not edges.has(key): edges[key] = []
			edges[key].append(Vector2i(a,b))
	var sealed: bool = true
	var oriented: bool = true
	for key: Vector2i in edges:
		var uses: Array = edges[key]
		if key.x>=joint_start or key.y>=joint_start:
			sealed = sealed and uses.size()==2
			if uses.size()==2: oriented = oriented and uses[0]==Vector2i(uses[1].y,uses[1].x)
			connected += 1
	check(connected>500 and sealed,"new shoulder patches have no exposed edges")
	check(oriented,"connected shoulder faces have consistent native winding")
	var poses: Array[Array] = [arrays]
	poses.append_array(geometry.surface_get_blend_shape_arrays(1))
	for pose: int in range(poses.size()):
		var vertices: PackedVector3Array = poses[pose][Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = poses[pose][Mesh.ARRAY_NORMAL]
		var finite: bool = vertices.size()==points.size()
		var fixed: bool = true
		var forearm: bool = true
		for vertex: int in range(vertices.size()): finite = finite and vertices[vertex].is_finite() and normals[vertex].is_finite() and normals[vertex].length_squared()>0.8
		for vertex: int in range(prefix): fixed = fixed and vertices[vertex]==points[vertex]
		var old_pose: Array = before if pose==0 else old.surface_get_blend_shape_arrays(1)[pose-1]
		for side: int in range(2):
			for vertex: int in range(11*17,21*17):
				var index: int = prefix+side*21*17+vertex
				forearm = forearm and vertices[index].distance_to(old_pose[Mesh.ARRAY_VERTEX][index]) < (0.00001 if vertex < 12*17 else 0.0000001)
		check(finite,"finite unit-normal shoulder pose "+str(pose))
		check(fixed,"supported body stays fixed in steering pose "+str(pose))
		check(forearm,"firm elbow/forearm/wrist positions retained in pose "+str(pose))
	print("KART_SHOULDER_FIT ",checks," checks, ",failures," failures; sewn edges ",connected)
	quit(1 if failures else 0)
