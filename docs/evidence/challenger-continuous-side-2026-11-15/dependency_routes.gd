extends SceneTree
func _initialize() -> void:
	var prefix: String="res://../build/challenger-continuous-side-2026-11-15/assets/"
	var paths: Array=JSON.parse_string(FileAccess.get_file_as_string(prefix+"changed-now.json"))
	var result: Dictionary={}
	for path: String in paths:result[path]=preload("res://vehicle/prepared_asset_sources.gd").vehicles_for(path)
	FileAccess.open(prefix+"dependency-routes.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("COMPILED_MODEL_ROUTES ",result.size()," changed inputs checked")
	quit()
