extends SceneTree
func _initialize()->void:
	var result: Dictionary={"sources":{},"revisions":{}}
	for id: String in VehicleCatalog.IDS:
		result.sources[id]=preload("res://vehicle/modular_car_base.gd").source_hashes(id)
		result.revisions[id]=preload("res://vehicle/modular_car_base.gd").build_revision(id)
	var output: String="res://../source-hashes.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--source-out="):output=argument.trim_prefix("--source-out=")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("QUALIFIED_SOURCES ",result.sources.size());quit()
