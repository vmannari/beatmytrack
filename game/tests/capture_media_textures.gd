extends SceneTree
## Imported base-level pixels and stored sizes, for offline compression comparison.

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var stage: String = "before"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--media-stage="): stage = arg.trim_prefix("--media-stage=")
	assert(stage in ["before", "after"])
	var directory: String = "res://../build/media-compression/textures/" + stage
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var records: Array[Dictionary] = []
	for folder: String in ["auth", "editor", "hud", "menu", "textures"]:
		for file: String in DirAccess.get_files_at("res://assets/" + folder):
			if not file.ends_with(".png"): continue
			var path: String = "res://assets/" + folder + "/" + file
			var texture: Texture2D = load(path) as Texture2D
			assert(texture != null, path)
			var image: Image = texture.get_image()
			image.convert(Image.FORMAT_RGBA8)
			assert(image.save_png(directory.path_join(folder + "--" + file)) == OK)
			records.append({"path": path, "width": texture.get_width(), "height": texture.get_height(),
				"mipmaps": image.has_mipmaps()})
	var output: FileAccess = FileAccess.open(directory.path_join("inventory.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(records, "\t") + "\n")
	print("MEDIA_TEXTURE_CAPTURE: ", records.size(), " imported images; stage=", stage)
	quit()
