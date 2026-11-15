extends RefCounted
static func smooth_wing(source: ArrayMesh) -> ArrayMesh:
	var a: Array=source.surface_get_arrays(0)
	var p: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var original: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	var n: PackedVector3Array=original.duplicate()
	var cells: Dictionary={}
	for i: int in range(p.size()):
		var cell:=Vector3i((p[i]/.05).floor())
		if not cells.has(cell):cells[cell]=[]
		cells[cell].append(i)
	for i: int in range(p.size()):
		if absf(p[i].x)<.65 or p[i].z> -1.55 or p[i].y<.53 or p[i].y>.85:continue
		var cell:=Vector3i((p[i]/.05).floor())
		var total:=Vector3.ZERO
		for dx: int in range(-1,2):
			for dy: int in range(-1,2):
				for dz: int in range(-1,2):
					for j: int in cells.get(cell+Vector3i(dx,dy,dz),[]):
						var distance: float=p[i].distance_to(p[j])
						if distance>.05 or original[i].dot(original[j])<0.0:continue
						total+=original[j]*exp(-pow(distance/.025,2))
		n[i]=total.normalized()
	a[Mesh.ARRAY_NORMAL]=n
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	for meta: StringName in source.get_meta_list():mesh.set_meta(meta,source.get_meta(meta))
	return mesh

static func rebuild(source: ArrayMesh) -> ArrayMesh:
	var a: Array=source.surface_get_arrays(0)
	var p: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=a[Mesh.ARRAY_INDEX]
	var faces: Array=[]
	var by_position: Dictionary={}
	var references: Dictionary={}
	for offset: int in range(0,indices.size(),3):
		var v: Array=[p[indices[offset]],p[indices[offset+1]],p[indices[offset+2]]]
		var normal: Vector3=-(v[1]-v[0]).cross(v[2]-v[0])
		faces.append(normal)
		for i: int in range(3):
			var key: Vector3=v[i].snapped(Vector3.ONE*.000001)
			if not by_position.has(key):by_position[key]=[]
			by_position[key].append(faces.size()-1)
			references[indices[offset+i]]=faces.size()-1
	var n: PackedVector3Array=a[Mesh.ARRAY_NORMAL]
	for i: int in range(p.size()):
		var total: Vector3=Vector3.ZERO
		var own: Vector3=faces[references[i]].normalized()
		for face: int in by_position[p[i].snapped(Vector3.ONE*.000001)]:
			if own.dot(faces[face].normalized())>.6691306:total+=faces[face]
		n[i]=total.normalized()
	a[Mesh.ARRAY_NORMAL]=n
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
	for meta: StringName in source.get_meta_list():mesh.set_meta(meta,source.get_meta(meta))
	return mesh
