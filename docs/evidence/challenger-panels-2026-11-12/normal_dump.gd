extends SceneTree
func _initialize() -> void:
	var output: Dictionary = {}
	for group: String in ["hood","body"]:
		var mesh: Mesh = load("res://assets/vehicles/challenger_hellcat_v1/simple_"+group+"_paint.res")
		var arrays: Array = mesh.surface_get_arrays(0)
		var positions: Array = []; var normals: Array = []
		for value: Vector3 in arrays[Mesh.ARRAY_VERTEX]:positions.append([value.x,value.y,value.z])
		for value: Vector3 in arrays[Mesh.ARRAY_NORMAL]:normals.append([value.x,value.y,value.z])
		output[group] = {"positions":positions,"normals":normals,"indices":Array(arrays[Mesh.ARRAY_INDEX])}
	var file := FileAccess.open("res://../build/challenger-panels-2026-11-12/native-normals.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output));file.close();quit()
