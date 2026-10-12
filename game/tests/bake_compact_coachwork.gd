extends SceneTree
## Explicit offline original-asset bake. Runtime loads these immutable meshes.
func _initialize() -> void: _bake.call_deferred()
func _bake() -> void:
	CompactCoachwork.use_baked = false
	CompactCoachwork.meshes.clear()
	var glazing=preload("res://vehicle/compact_glazing.gd")
	glazing.use_baked=false
	glazing.sheets.clear()
	var car := CarVisual.new()
	car.batch_parts = false
	root.add_child(car)
	var directory: String = ProjectSettings.globalize_path(CompactCoachwork.ASSET_ROOT)
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Could not prepare the owned Compact mesh directory")
		quit(1)
		return
	var bytes: int = 0
	var resources: Dictionary=CompactCoachwork.meshes.duplicate()
	resources.merge(glazing.sheets)
	for key: String in resources:
		var path: String = CompactCoachwork.ASSET_ROOT.path_join(key+".res")
		if ResourceSaver.save(resources[key],path,ResourceSaver.FLAG_COMPRESS) != OK:
			push_error("Could not bake "+key)
			quit(1)
			return
		var file := FileAccess.open(path,FileAccess.READ)
		bytes += file.get_length()
		file.close()
	print("COMPACT_COACHWORK_BAKE: ",resources.size()," original meshes, ",bytes," bytes")
	car.queue_free()
	await process_frame
	quit()
