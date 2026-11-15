extends SceneTree
func _initialize() -> void:
	var catalog: Dictionary=load("res://../build/volt-reflection-smoothing-2026-11-15/survey.res").get_meta("catalog")
	var data: Dictionary={}
	for label: String in catalog:
		if label=="ReferenceRear":continue
		var a: Array=catalog[label].native.surface_get_arrays(0)
		var queries: Array=[]
		for value: Vector3 in catalog[label].native.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:queries.append([value.x,value.y,value.z])
		var p: Array=[];var n: Array=[]
		for value: Vector3 in a[Mesh.ARRAY_VERTEX]:p.append([value.x,value.y,value.z])
		for value: Vector3 in a[Mesh.ARRAY_NORMAL]:n.append([value.x,value.y,value.z])
		data[label]={"queries":queries,"positions":p,"normals":n,"indices":Array(a[Mesh.ARRAY_INDEX])}
	FileAccess.open("res://../build/volt-reflection-smoothing-2026-11-15/native-field.json",FileAccess.WRITE).store_string(JSON.stringify(data));quit()
