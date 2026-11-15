extends SceneTree
## Native mesh resources from the offline simplified owner-supplied model.
const SOURCE: String = "res://../build/challenger-panels-2026-11-12/converted-final/"
const DEST: String = "res://assets/vehicles/challenger_hellcat_v1/"
var packed_fender_repairs: Dictionary = {}
var packed_fender_vertex_fairing: Dictionary = {}

func fender_triangle_score(face: Array[int], points: PackedVector3Array, normals: PackedVector3Array) -> float:
	var geometric: Vector3 = -(points[face[1]]-points[face[0]]).cross(points[face[2]]-points[face[0]])
	if geometric.length_squared() < 1e-18: return -1.0
	geometric = geometric.normalized()
	return minf(geometric.dot(normals[face[0]]),minf(geometric.dot(normals[face[1]]),geometric.dot(normals[face[2]])))

func repair_fender_diagonals(arrays: Array, label: String) -> int:
	# GLTF/native packing can expose a poor diagonal in a very thin constrained
	# border quad. Flip only a shared interior edge of the continuous wing chart.
	# Existing positions, boundary edges, attributes and triangle count stay exact.
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var repairs: int = 0
	var vertex_repairs: int = 0
	for attempt: int in range(32):
		var edges: Dictionary = {}
		for offset: int in range(0,indices.size(),3):
			for corner: int in range(3):
				var a: int = indices[offset+corner]; var b: int = indices[offset+(corner+1)%3]
				var key := Vector2i(mini(a,b),maxi(a,b))
				if not edges.has(key): edges[key] = []
				edges[key].append(offset)
		var repaired: bool = false
		for offset: int in range(0,indices.size(),3):
			var face: Array[int] = [indices[offset],indices[offset+1],indices[offset+2]]
			var centre: Vector3 = (points[face[0]]+points[face[1]]+points[face[2]])/3.0
			if centre.x<.70 or centre.y<.80 or centre.y>1.03 or centre.z< -2.20 or centre.z> -.70: continue
			if fender_triangle_score(face,points,normals)>= -.02: continue
			for corner: int in range(3):
				var a: int=face[corner]; var b: int=face[(corner+1)%3]; var c: int=face[(corner+2)%3]
				var members: Array=edges[Vector2i(mini(a,b),maxi(a,b))]
				if members.size()!=2: continue
				var other: int=int(members[0]) if int(members[1])==offset else int(members[1])
				var d: int= -1
				for k: int in range(3):
					var vertex: int=indices[other+k]
					if vertex!=a and vertex!=b: d=vertex
				if d<0 or d==c: continue
				if normals[a].dot(normals[d])<.8 or normals[b].dot(normals[c])<.8: continue
				var first: Array[int]=[c,a,d]; var second: Array[int]=[c,d,b]
				# Positive projected area on both triangles proves the new
				# diagonal covers the same convex Y/Z domain without crossing.
				var n1: Vector3= -(points[a]-points[c]).cross(points[d]-points[c])
				var n2: Vector3= -(points[d]-points[c]).cross(points[b]-points[c])
				if n1.x<=1e-10 or n2.x<=1e-10: continue
				if minf(fender_triangle_score(first,points,normals),fender_triangle_score(second,points,normals))<.2: continue
				for k: int in range(3): indices[offset+k]=first[k]; indices[other+k]=second[k]
				repairs+=1; repaired=true; break
			if not repaired:
				# A constrained border can leave a concave quad with no valid
				# replacement diagonal. Fair only an interior station in X until
				# every incident face agrees with its retained chart tangents.
				# Y/Z, panel borders, normals and all triangle indices stay fixed.
				for vertex: int in face:
					var incident: Array[int]=[]; var interior: bool=true
					for at: int in range(0,indices.size(),3):
						for k: int in range(3):
							if indices[at+k]!=vertex: continue
							incident.append(at)
							for neighbor: int in [indices[at+(k+1)%3],indices[at+(k+2)%3]]:
								if edges[Vector2i(mini(vertex,neighbor),maxi(vertex,neighbor))].size()!=2: interior=false
					if not interior or incident.size()<3: continue
					var original: Vector3=points[vertex]
					for step: int in range(1,41):
						for direction: float in [-1.0,1.0]:
							points[vertex]=original+Vector3(direction*step*.00005,0,0)
							var valid: bool=true
							for at: int in incident:
								var triangle: Array[int]=[indices[at],indices[at+1],indices[at+2]]
								if fender_triangle_score(triangle,points,normals)<.35: valid=false; break
							if valid: vertex_repairs+=1; repaired=true; break
						if repaired: break
					if repaired: break
					points[vertex]=original
			if repaired: break
		if not repaired: break
	arrays[Mesh.ARRAY_INDEX]=indices
	arrays[Mesh.ARRAY_VERTEX]=points
	packed_fender_repairs[label]=repairs
	packed_fender_vertex_fairing[label]=vertex_repairs
	return repairs+vertex_repairs

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

func symmetric_attributes(arrays: Array, label: String = "") -> void:
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
	assert(ids.size() == indices.size(),"Native symmetry retains the qualified source triangle count: "+label+" "+str(ids.size())+"/"+str(indices.size()))
	arrays[Mesh.ARRAY_VERTEX] = p; arrays[Mesh.ARRAY_NORMAL] = n; arrays[Mesh.ARRAY_INDEX] = ids
	arrays[Mesh.ARRAY_TEX_UV] = u; arrays[Mesh.ARRAY_COLOR] = c; arrays[Mesh.ARRAY_TANGENT] = null

func authored_contour_attributes(arrays: Array) -> void:
	var p: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var encoded: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var blocks: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert(encoded.size() == p.size() and blocks.size() == p.size(),"Factory contour retains authored pair identifiers")
	var pairs: Dictionary = {}
	for i: int in range(p.size()):
		var identity: int = roundi(absf(encoded[i].x))-1+1024*roundi(blocks[i].x)
		assert(identity >= 0,"Factory contour pair identifier is valid")
		if not pairs.has(identity): pairs[identity] = []
		pairs[identity].append(i)
	var uv := PackedVector2Array(); uv.resize(p.size())
	var tangent := PackedFloat32Array(); tangent.resize(p.size()*4)
	for identity: int in pairs:
		var members: Array = pairs[identity]
		var negative: Vector3; var positive: Vector3
		var has_negative: bool = false; var has_positive: bool = false
		for i: int in members:
			if encoded[i].x < 0: negative = p[i]; has_negative = true
			else: positive = p[i]; has_positive = true
		assert(has_negative and has_positive,"Every authored contour pair has both sides")
		var half: float = negative.distance_to(positive)*0.5
		assert(half > 0.00005 and half < 0.006,"Authored contour keeps its physical width: "+str(identity)+" "+str(half))
		for i: int in members:
			var side: float = -1.0 if encoded[i].x < 0 else 1.0
			var direction: Vector3 = (negative-positive).normalized() if side < 0 else (positive-negative).normalized()
			uv[i] = Vector2(side,half)
			for axis: int in range(3): tangent[i*4+axis] = direction[axis]
			tangent[i*4+3] = 1.0
	arrays[Mesh.ARRAY_TEX_UV] = uv; arrays[Mesh.ARRAY_TEX_UV2] = null; arrays[Mesh.ARRAY_TANGENT] = tangent

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
			if conversion.tiers[tier].get("clean_panels",{}).has("manufactured_exterior") and ((group == "body" and role in ["dark","accent"]) or (group == "aero" and role == "accent")):
				# These fitted optical seats share the repaired paint boundary;
				# further generic reduction can put paint through the applique.
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
					if group == "body" and role == "paint": repair_fender_diagonals(arrays,tier)
					if group in ["body","hood","aero","window_seal"] and role != "contour": symmetric_attributes(arrays,tier+"/"+group+"/"+role)
					if group in ["head_right","tail_right"]: lamp_arrays[group+"/"+role] = arrays.duplicate(true)
					if group in ["head_left","tail_left"]: arrays = reflected(lamp_arrays[group.replace("_left","_right")+"/"+role])
				if group == "body" and role == "contour" and conversion.tiers[tier].get("clean_panels",{}).get("manufactured_exterior",{}).has("factory_body"):
					authored_contour_attributes(arrays)
					native.set_meta("pixel_integrated_contour",true)
				# Native fitted parts have UVs/colours. Explicit neutral attributes
				# keep direct and separately batched assemblies byte-equivalent.
				var final_count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				if arrays[Mesh.ARRAY_TEX_UV] == null:
					var uv := PackedVector2Array(); uv.resize(final_count); arrays[Mesh.ARRAY_TEX_UV] = uv
				if arrays[Mesh.ARRAY_COLOR] == null:
					var colors := PackedColorArray(); colors.resize(final_count); colors.fill(Color.WHITE); arrays[Mesh.ARRAY_COLOR] = colors
				triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3
				native.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var file: String = tier+"_"+group+"_"+role+".res"
			if clean and group == "body" and role == "paint":
				var packed: Array=native.surface_get_arrays(0)
				if repair_fender_diagonals(packed,tier+"/packed")>0:
					symmetric_attributes(packed,tier+"/packed-border")
					var corrected := ArrayMesh.new()
					for meta: StringName in native.get_meta_list(): corrected.set_meta(meta,native.get_meta(meta))
					corrected.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,packed)
					native=corrected
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
	provenance.packed_fender_diagonal_repairs = packed_fender_repairs
	provenance.packed_fender_interior_station_fairing = packed_fender_vertex_fairing
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
