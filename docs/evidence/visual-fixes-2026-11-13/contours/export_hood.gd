extends SceneTree
func _initialize() -> void:
	var out: Dictionary={}
	for group: String in ["body","hood"]:
		var mesh: ArrayMesh=load("res://assets/vehicles/challenger_hellcat_v1/simple_"+group+"_paint.res")
		var a: Array=mesh.surface_get_arrays(0)
		var vertices: Array=[]
		var normals: Array=[]
		for p: Vector3 in a[Mesh.ARRAY_VERTEX]:vertices.append([p.x,p.y,p.z])
		for p: Vector3 in a[Mesh.ARRAY_NORMAL]:normals.append([p.x,p.y,p.z])
		out[group]={"vertices":vertices,"normals":normals,"indices":Array(a[Mesh.ARRAY_INDEX])}
	var file:=FileAccess.open("res://../build/visual-fixes-2026-11-13/contours/hood-arrays.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(out));file.close();quit()
