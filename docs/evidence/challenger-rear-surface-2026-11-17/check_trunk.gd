extends SceneTree
func _initialize() -> void:
	var checks: int=0
	var failures: int=0
	var report: Dictionary={}
	for tier: String in ["simple","full"]:
		var prefix: String="res://../build/challenger-rear-surface-2026-11-17/native/"
		var paint: ArrayMesh=load(prefix+tier+"_body_paint.res")
		var skin: TriangleMesh=paint.generate_triangle_mesh()
		var contour: ArrayMesh=load(prefix+tier+"_body_contour.res")
		var arrays: Array=contour.surface_get_arrays(0)
		var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
		var count: int=0
		var misses: int=0
		var minimum: float=INF
		var maximum: float=-INF
		var width_error: float=0
		for i: int in range(points.size()):
			var p: Vector3=points[i]
			if p.z<1.4:continue
			count+=1
			width_error=maxf(width_error,absf(uv[i].y-.00125))
			var hit: Dictionary=skin.intersect_ray(p+Vector3.UP*.04,Vector3.DOWN)
			if hit.is_empty():
				misses+=1
				continue
			var gap: float=p.y-hit.position.y
			minimum=minf(minimum,gap)
			maximum=maxf(maximum,gap)
		for passed: bool in [count==80,misses==0,minimum>=.0005 and maximum<=.004,width_error<.0001]:
			checks+=1
			if not passed:failures+=1
		report[tier]={"samples":count,"misses":misses,"gap_mm":[minimum*1000,maximum*1000],"half_width_maximum_error_mm":width_error*1000}
	report.checks=checks
	report.failures=failures
	FileAccess.open("res://../docs/evidence/challenger-rear-surface-2026-11-17/candidate-trunk.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TRUNK_SEAMS ",JSON.stringify(report))
	quit(1 if failures else 0)
