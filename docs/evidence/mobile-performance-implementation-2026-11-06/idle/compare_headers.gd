extends SceneTree
func difference(first: String, second: String) -> Dictionary:
	var a: Image = Image.load_from_file(first)
	var b: Image = Image.load_from_file(second)
	a.convert(Image.FORMAT_RGBA8)
	b.convert(Image.FORMAT_RGBA8)
	var left: PackedByteArray = a.get_data()
	var right: PackedByteArray = b.get_data()
	var result: Dictionary = {"changed_pixels":0,"max_channel":0,"absolute_error":0,"exact":left==right}
	for pixel: int in range(left.size()/4):
		var changed: bool = false
		for channel: int in range(4):
			var error: int = absi(left[pixel*4+channel]-right[pixel*4+channel])
			result.max_channel = maxi(result.max_channel,error)
			result.absolute_error += error
			changed = changed or error > 0
		if changed: result.changed_pixels += 1
	return result
func _initialize() -> void:
	var folder: String = OS.get_cmdline_user_args()[0]
	var rows: Array[Dictionary] = []
	for vehicle: String in ["compact","kart","forklift","electric","hovercraft"]:
		rows.append({"vehicle":vehicle,"candidate":difference(folder.path_join(vehicle+"-before.png"),folder.path_join(vehicle+".png")),"control":difference(folder.path_join(vehicle+"-before.png"),folder.path_join(vehicle+"-control-repeat.png"))})
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("HEADER_COMPARISONS ",JSON.stringify(rows))
	quit()
