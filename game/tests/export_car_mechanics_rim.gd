extends SceneTree
func _initialize() -> void:
	var catalog: Dictionary=load("res://../build/car-mechanics-2026-11-17/survey.res").get_meta("catalog")
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/evidence/car-mechanics-2026-11-17/survey.json"))
	var helper=load("res://tests/compile_car_mechanics_lods.gd").new()
	for row: Dictionary in rows:
		if row.name!="DishedMagnesiumRim":continue
		var source: Mesh=catalog[row.key].source;var a: Array=source.surface_get_arrays(0);var points: Array=[]
		for p: Vector3 in a[Mesh.ARRAY_VERTEX]:points.append([p.x,p.y,p.z])
		FileAccess.open("res://../build/car-mechanics-2026-11-17/rim-proof.json",FileAccess.WRITE).store_string(JSON.stringify({"vertices":points,"before":Array(a[Mesh.ARRAY_INDEX]),"after":Array(helper.inner_rim(source))}))
		break
	helper.free();quit()
