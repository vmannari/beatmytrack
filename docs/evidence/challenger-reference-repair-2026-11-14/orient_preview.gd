extends SceneTree
func _initialize() -> void:
	for tier: String in ["simple","full"]:
		var path: String = "res://../build/challenger-reference-repair-2026-11-14/native/"+tier+"_body_paint.res"
		var mesh: ArrayMesh = load(path)
		var a: Array = mesh.surface_get_arrays(0)
		var p: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var ids: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var common: Dictionary = {};var flipped: int = 0;var changed: int = 0
		for i: int in range(0,ids.size(),3):
			var v: Array[int] = [ids[i],ids[i+1],ids[i+2]]
			var cross: Vector3 = (p[v[1]]-p[v[0]]).cross(p[v[2]]-p[v[0]])
			var centre: Vector3 = (p[v[0]]+p[v[1]]+p[v[2]])/3
			var expected_out: Vector3 = n[v[0]]+n[v[1]]+n[v[2]]
			if centre.z > -2.095 and centre.z < -.48 and absf(centre.x) > .60 and centre.y < 1.08: expected_out = Vector3(signf(centre.x),0,0)
			elif centre.z <= -2.095: expected_out = Vector3(centre.x/.84,0,(centre.z+1.9)*4)
			elif centre.z > 1.70 and absf(centre.x) > .60 and centre.y > .85: expected_out = Vector3(centre.x,1.1 if centre.y>.916 else 0.0,maxf(0,centre.z-1.75))
			if cross.dot(expected_out) > 0:
				ids[i+1]=v[2];ids[i+2]=v[1];cross=-cross;flipped+=1
			var normal: Vector3 = -cross.normalized()
			for j: int in range(3):
				var one: Vector3 = (p[v[(j+1)%3]]-p[v[j]]).normalized()
				var two: Vector3 = (p[v[(j+2)%3]]-p[v[j]]).normalized()
				var weight: float = acos(clampf(one.dot(two),-1,1))
				var key: Vector3 = p[v[j]].snapped(Vector3.ONE*0.00001)
				common[key]=(common.get(key,Vector3.ZERO) as Vector3)+normal*weight
		for i: int in range(p.size()):
			var q: Vector3 = p[i]
			var affected: bool = (q.z < -1.72) or (q.z < -0.48 and q.z > -1.75 and absf(q.x) > .60 and q.y < 1.05) or (q.z > 1.70 and absf(q.x) > .60 and q.y > .85)
			if not affected: continue
			var expected: Vector3 = (common[q.snapped(Vector3.ONE*.00001)] as Vector3).normalized()
			if n[i].dot(expected)<cos(deg_to_rad(15.0)):
				n[i]=expected;changed+=1
		a[Mesh.ARRAY_NORMAL]=n;a[Mesh.ARRAY_INDEX]=ids;a[Mesh.ARRAY_TANGENT]=null
		var result := ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a)
		result.set_meta("car_surface_guide_locked",true)
		assert(ResourceSaver.save(result,path)==OK)
		print("ORIENT_PREVIEW ",tier," flipped=",flipped," normals=",changed)
	quit()
