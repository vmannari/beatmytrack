extends SceneTree
func _initialize() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var first: Image = Image.load_from_file(arguments[0])
	var second: Image = Image.load_from_file(arguments[1])
	var result: Dictionary = {"same_size":first.get_size()==second.get_size(),"changed_pixels":0,"max_channel":0}
	first.convert(Image.FORMAT_RGBA8)
	second.convert(Image.FORMAT_RGBA8)
	var left: PackedByteArray = first.get_data()
	var right: PackedByteArray = second.get_data()
	if result.same_size:
		for pixel: int in range(left.size()/4):
			var changed: bool = false
			for channel: int in range(4):
				var difference: int = absi(left[pixel*4+channel]-right[pixel*4+channel])
				result.max_channel = maxi(result.max_channel,difference)
				changed = changed or difference > 0
			if changed: result.changed_pixels += 1
	result.exact = left == right
	print("HEADER_IMAGE_COMPARISON ",JSON.stringify(result))
	FileAccess.open(OS.get_environment("BMT_LOADING_OUTPUT"),FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	quit()
