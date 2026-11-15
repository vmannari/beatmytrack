extends SceneTree
func _initialize() -> void:
	var path: String=""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--input="):path=arg.trim_prefix("--input=")
	var paths: Array=JSON.parse_string(FileAccess.get_file_as_string(path))
	var result: Dictionary={}
	for item: String in paths:result[item]=preload("res://vehicle/prepared_asset_sources.gd").vehicles_for(item)
	FileAccess.open(path+".routes.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("MODEL_ROUTE_CHECK ",JSON.stringify(result))
	quit()
