extends SceneTree
## Inspect the actual prepared geometry for open fabricated edges and clear vents.
var checks: int = 0
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+label)
func point_key(point: Vector3) -> String:
	return str(Vector3i((point*100000.0).round()))
func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CompactKits.ASSET_ROOT.path_join("manifest.json")))
	for key: String in manifest.meshes:
		var solid: bool = key.begins_with("body6/") and any_fragment(key,["/sill","/valance","/arch","/diffusertray","/splitterdeck","/flap"])
		solid = solid or key.begins_with("rim6/") and "/spoke" in key
		solid = solid or key.begins_with("hood6/") and key.trim_suffix("/simple").get_file().begins_with("louvre")
		solid = solid or key.begins_with("aero6/") and any_fragment(key,["/upright","/brace","/neck","/hoopleg","/pylon","/gurney","/mouldedroot"])
		if not solid: continue
		var mesh: ArrayMesh = load(CompactKits.ASSET_ROOT.path_join("meshes/"+str(manifest.meshes[key].file)))
		var arrays: Array = mesh.surface_get_arrays(0)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if "/valancetrue" in key:
			var clear_plate: bool = true
			for point: Vector3 in points:
				if absf(point.x)<0.220 and point.z>2.114 and point.y>CompactRearDesign.PLATE_CENTER-0.110-0.001: clear_plate = false
			check(clear_plate,"actual rear apron clears the original plate frame "+key)
		if key.begins_with("body6/"):
			var clear_tyres: bool = true
			for point: Vector3 in points:
				if absf(point.x)>0.69 and absf(point.x)<0.98:
					for axle: float in [-1.28,1.28]:
						if Vector2(point.y-0.37,point.z-axle).length()<0.382: clear_tyres = false
			check(clear_tyres,"fabricated body clears the unchanged tyre envelope "+key)
		var edges: Dictionary = {}
		var volume: float = 0
		for index: int in range(0,indices.size(),3):
			var a: Vector3 = points[indices[index]]
			var b: Vector3 = points[indices[index+1]]
			var c: Vector3 = points[indices[index+2]]
			volume += a.cross(b).dot(c)/6.0
			for edge: int in range(3):
				var p: String = point_key(points[indices[index+edge]])
				var q: String = point_key(points[indices[index+(edge+1)%3]])
				if p==q: continue
				var label: String = p+"/"+q if p<q else q+"/"+p
				edges[label] = int(edges.get(label,0))+1
		var closed: bool = true
		for count: int in edges.values():
			if count!=2: closed = false
		check(closed,"closed fabricated section "+key)
		check(absf(volume)>0.00000002,"real solid thickness "+key)
	# Rays through the eight cooling windows must pass the actual wheel face.
	for side: float in [-1,1]:
		for simple: String in ["","/simple"]:
			var key: String = "rim6/rallydisc/"+str(side)+"/disctrue"+simple
			# Bool names use GDScript's capitalised string representation.
			if not manifest.meshes.has(key): key = key.replace("disctrue","discTrue")
			check(manifest.meshes.has(key),"prepared rally disc back face exists")
			if not manifest.meshes.has(key): continue
			var mesh: ArrayMesh = load(CompactKits.ASSET_ROOT.path_join("meshes/"+str(manifest.meshes[key].file)))
			var arrays: Array = mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for index: int in range(8):
				var a: float = (index/8.0+0.0625)*TAU
				var p := Vector3(side*0.18,sin(a)*0.150,cos(a)*0.150)
				var q := Vector3(side*0.08,p.y,p.z)
				var open: bool = true
				for triangle: int in range(0,indices.size(),3):
					if Geometry3D.segment_intersects_triangle(p,q,points[indices[triangle]],points[indices[triangle+1]],points[indices[triangle+2]])!=null: open = false
				check(open,"actual open cooling window "+str(index)+"/"+str(side)+simple)
	print("COMPACT_KIT_CONSTRUCTION: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
func any_fragment(key: String, parts: Array[String]) -> bool:
	for part: String in parts:
		if part in key: return true
	return false
