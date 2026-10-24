extends SceneTree
## Keep this Pine/Winter probe independent of the shared texture import cache.
## NativeTrackVisual's unrelated Desert static luminance sample reads pixels
## without decompressing the imported image. Use the same original PNG pixels
## for that resource before loading the profiling script; no asset is edited.
func _initialize() -> void:
	var texture := ImageTexture.create_from_image(Image.load_from_file("res://assets/textures/desert_compacted_road_v3.png"))
	texture.take_over_path("res://assets/textures/desert_compacted_road_v3.png")
	var probe: Script = load("res://tests/profile_creator_object_limit_higher.gd" if "--higher-counts" in OS.get_cmdline_user_args() else "res://tests/profile_creator_object_limit.gd")
	set_script(probe)
	call_deferred("run")
