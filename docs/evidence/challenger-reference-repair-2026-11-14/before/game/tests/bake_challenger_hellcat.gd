extends SceneTree
## Native mesh resources from the offline simplified owner-supplied model.
const SOURCE: String = "res://../build/challenger-panels-2026-11-12/converted-final/"
const DEST: String = "res://assets/vehicles/challenger_hellcat_v1/"

func _initialize() -> void: run.call_deferred()

func source_pose(part: Node3D,scene: Node3D) -> Transform3D:
	var pose: Transform3D = part.transform
	var parent: Node3D = part.get_parent()
	while parent != scene: pose = parent.transform*pose; parent = parent.get_parent()
	return pose

func reflected(arrays: Array) -> Array:
	var copy: Array = arrays.duplicate(true)
	var points: PackedVector3Array = copy[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = copy[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = copy[Mesh.ARRAY_INDEX]
	for i: int in range(points.size()): points[i].x = -points[i].x; normals[i].x = -normals[i].x
	for i: int in range(0,indices.size(),3):
		var first: int = indices[i]; indices[i] = indices[i+2]; indices[i+2] = first
	copy[Mesh.ARRAY_VERTEX] = points; copy[Mesh.ARRAY_NORMAL] = normals; copy[Mesh.ARRAY_INDEX] = indices
	copy[Mesh.ARRAY_TANGENT] = null
	return copy

func symmetric_attributes(arrays: Array) -> void:
	# Build both halves from the same final packed right-hand triangles. This
	# also preserves hard-normal splits that GLTF may weld differently per side.
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var low: float = INF; var high: float = -INF
	for p: Vector3 in points: low = minf(low,p.x); high = maxf(high,p.x)
	var precision: float = (high-low)/65535.0+0.000002
	for i: int in range(points.size()):
		if absf(points[i].x) <= precision: points[i].x = 0; normals[i].x = 0; normals[i] = normals[i].normalized()
	var p := PackedVector3Array(); var n := PackedVector3Array()
	var u := PackedVector2Array(); var c := PackedColorArray(); var ids := PackedInt32Array()
	var mapping: Dictionary = {}; var centre_faces: Dictionary = {}
	for i: int in range(0,indices.size(),3):
		var face: Array[int] = [indices[i],indices[i+1],indices[i+2]]
		if points[face[0]].x < 0 or points[face[1]].x < 0 or points[face[2]].x < 0: continue
		if points[face[0]].x == 0 and points[face[1]].x == 0 and points[face[2]].x == 0:
			var positions: Array[String] = [str(points[face[0]]),str(points[face[1]]),str(points[face[2]])]; positions.sort()
			var key: String = str(positions)
			if centre_faces.has(key): continue
			centre_faces[key] = true
		for vertex: int in face:
			if not mapping.has(vertex):
				mapping[vertex] = p.size(); p.append(points[vertex]); n.append(normals[vertex])
				u.append(uv[vertex] if not uv.is_empty() else Vector2.ZERO)
				c.append(colors[vertex] if not colors.is_empty() else Color.WHITE)
			ids.append(int(mapping[vertex]))
	var count: int = p.size(); var triangle_indices: int = ids.size()
	for i: int in range(count):
		var point: Vector3 = p[i]; var normal: Vector3 = n[i]; point.x = -point.x; normal.x = -normal.x
		p.append(point); n.append(normal); u.append(u[i]); c.append(c[i])
	for i: int in range(0,triangle_indices,3): ids.append_array(PackedInt32Array([ids[i+2]+count,ids[i+1]+count,ids[i]+count]))
	assert(ids.size() == indices.size(),"Native symmetry retains the qualified source triangle count")
	arrays[Mesh.ARRAY_VERTEX] = p; arrays[Mesh.ARRAY_NORMAL] = n; arrays[Mesh.ARRAY_INDEX] = ids
	arrays[Mesh.ARRAY_TEX_UV] = u; arrays[Mesh.ARRAY_COLOR] = c; arrays[Mesh.ARRAY_TANGENT] = null

func run() -> void:
	var source: String = SOURCE
	var destination: String = DEST
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): source = argument.trim_prefix("--source=").trim_suffix("/")+"/"
		if argument.begins_with("--dest="): destination = argument.trim_prefix("--dest=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
	var profile: String = FileAccess.get_file_as_string(source+"hood_profile.json")
	assert((JSON.parse_string(profile) as Dictionary).schema == "challenger-hood-profile-1")
	var profile_file := FileAccess.open(destination+"hood_profile.json",FileAccess.WRITE)
	profile_file.store_string(profile); profile_file.close()
	var result: Dictionary = {"schema":"challenger-hellcat-1","tiers":{}}
	var conversion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source+"manifest.json"))
	for tier: String in ["full","simple"]:
		var document := GLTFDocument.new(); var state := GLTFState.new()
		assert(document.append_from_file(ProjectSettings.globalize_path(source+tier+".glb"),state) == OK)
		var scene: Node3D = document.generate_scene(state)
		var entries: Array = []
		var parts: Array[Node] = scene.find_children("*","MeshInstance3D",true,false)
		parts.sort_custom(func(a: Node,b: Node) -> bool: return str(a.name) > str(b.name))
		var lamp_arrays: Dictionary = {}
		var clean: bool = conversion.tiers[tier].has("clean_panels")
		var paint_part: MeshInstance3D = scene.find_child("body__paint",true,false)
		var paint_pose: Transform3D = source_pose(paint_part,scene)
		var paint_guide: TriangleMesh = paint_part.mesh.generate_triangle_mesh()
		for part: MeshInstance3D in parts:
			var label: String = str(part.name)
			var split: PackedStringArray = label.split("__")
			assert(split.size() == 2,label)
			var group: String = split[0]; var role: String = split[1].get_slice(".",0)
			var pose: Transform3D = source_pose(part,scene)
			var pivot := Vector3.ZERO
			if group.begins_with("wheel_"):
				pivot = Vector3(-0.83 if group.ends_with("_L") else 0.83,0.37,-1.28 if "_Ft_" in group else 1.28)
			var native := ArrayMesh.new(); var triangles: int = 0
			if clean and ((group in ["body","hood"] and role in ["paint","contour"]) or group.begins_with("tail_") or (group == "body" and role in ["red","lens_red","reverse"])):
				native.set_meta("car_surface_guide_locked",true)
			if role == "contour" and FileAccess.file_exists(source+"bonnet_contour.json"):
				var marking: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source+"bonnet_contour.json"))
				native.set_meta("bonnet_contour_baked",bool(marking.get("baked",false)))
			for index: int in range(part.mesh.get_surface_count()):
				var arrays: Array = part.mesh.surface_get_arrays(index)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				for vertex: int in range(vertices.size()):
					vertices[vertex] = pose*vertices[vertex]-pivot
					normals[vertex] = (pose.basis.inverse().transposed()*normals[vertex]).normalized()
					if clean and group == "body" and role == "red" and absf(vertices[vertex].x) > 0.75 and vertices[vertex].z < 1.99:
						var side: float = signf(vertices[vertex].x)
						var origin := Vector3(side*2,vertices[vertex].y,vertices[vertex].z)
						var hit: Dictionary = paint_guide.intersect_ray(paint_pose.affine_inverse()*origin,paint_pose.basis.inverse()*Vector3(-side,0,0))
						assert(not hit.is_empty(),"Rear side marker has a supported body surface")
						vertices[vertex].x = (paint_pose*hit.position).x+side*0.004
						normals[vertex] = (paint_pose.basis.inverse().transposed()*hit.normal).normalized()
				arrays[Mesh.ARRAY_VERTEX] = vertices; arrays[Mesh.ARRAY_NORMAL] = normals
				if clean:
					if group in ["body","hood","aero","window_seal"] and role != "contour": symmetric_attributes(arrays)
					if group in ["head_right","tail_right"]: lamp_arrays[group+"/"+role] = arrays.duplicate(true)
					if group in ["head_left","tail_left"]: arrays = reflected(lamp_arrays[group.replace("_left","_right")+"/"+role])
				# Native fitted parts have UVs/colours. Explicit neutral attributes
				# keep direct and separately batched assemblies byte-equivalent.
				if arrays[Mesh.ARRAY_TEX_UV] == null:
					var uv := PackedVector2Array(); uv.resize(vertices.size()); arrays[Mesh.ARRAY_TEX_UV] = uv
				if arrays[Mesh.ARRAY_COLOR] == null:
					var colors := PackedColorArray(); colors.resize(vertices.size()); colors.fill(Color.WHITE); arrays[Mesh.ARRAY_COLOR] = colors
				triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
				native.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var file: String = tier+"_"+group+"_"+role+".res"
			assert(ResourceSaver.save(native,destination+file) == OK)
			entries.append({"group":group,"role":role,"mesh":file,"triangles":triangles,"bounds":str(native.get_aabb())})
		result.tiers[tier] = entries
		scene.free()
	var output := FileAccess.open(destination+"manifest.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t")); output.close()
	var provenance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source+"manifest.json"))
	if conversion.tiers.simple.has("clean_panels"): provenance.native_symmetry = "one packed right-hand source supplies both halves and hard-normal splits; qualified triangle count retained"
	for tier: String in ["full","simple"]:
		var actual: int = 0
		for entry: Dictionary in result.tiers[tier]: actual += int(entry.triangles)
		assert(actual == int(provenance.tiers[tier].triangles),"Native geometry must match its complete conversion receipt: "+tier)
	provenance.erase("source")
	output = FileAccess.open(destination+"source.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(provenance,"\t")); output.close()
	if FileAccess.file_exists(source+"bonnet_contour.json"):
		var contour: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source+"bonnet_contour.json"))
		contour.source_mesh = "simple_hood_paint.res"
		contour.source_sha256 = FileAccess.get_sha256(destination+"simple_hood_paint.res")
		output = FileAccess.open(destination+"bonnet_contour.json",FileAccess.WRITE)
		output.store_string(JSON.stringify(contour,"\t")); output.close()
	print("CHALLENGER_NATIVE_BAKE ",JSON.stringify(result.tiers.keys()))
	quit()
