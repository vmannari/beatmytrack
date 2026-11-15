extends "res://tests/export_car_step10_proof.gd"
func _initialize() -> void:
	var directory: String="res://../build/volt-rear-corners-2026-11-15"
	var catalog: Dictionary=load(directory.path_join("survey.res")).get_meta("catalog")
	var result: Dictionary={}
	for label: String in ["ReferenceSide-1_0","ReferenceSide1_0"]:
		var row: Dictionary=catalog[label];var after: Mesh=load(directory.path_join("candidates").path_join(label+".res"))
		var bundle: Dictionary={}
		for key: String in ["current","native","after"]:
			var mesh: Mesh=after if key=="after" else row[key]
			bundle[key]={"vertices":vertices(mesh,0),"indices":indices(mesh,0),"fields":fields(mesh,0),"encoded":attributes(mesh,0)}
		result[label]=bundle
	FileAccess.open(directory.path_join("proof.json"),FileAccess.WRITE).store_string(JSON.stringify(result));quit()
