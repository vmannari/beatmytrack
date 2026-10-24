extends SceneTree
const DIRECTORY: String = "res://../docs/evidence/gameplay-f05-f10-2026-10-23/textures"
const DECODED: String = "res://../build/gameplay-f05-f10-2026-10-23/etc2-images"
const NAMES: Array[String] = ["desert_apron_v1","desert_compacted_road_v3","desert_sand_v2","dust_puff_v1","meadow_grass_v2","night_asphalt_wear_v1","night_industrial_ground_v1","painted_grass_v1","winter_ice_v1","winter_snow_v1"]
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var folder: String = ProjectSettings.globalize_path(DIRECTORY)
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DECODED))
	var rows: Array = []
	for name: String in NAMES:
		var texture: Texture2D = load("res://assets/textures/"+name+".png")
		if "android-artifacts" in OS.get_cmdline_user_args():
			assert(DisplayServer.get_name()=="headless")
			var settings := ConfigFile.new(); assert(settings.load("res://assets/textures/"+name+".png.import")==OK)
			var artifact := CompressedTexture2D.new(); assert(artifact.load(settings.get_value("remap","path.etc2"))==OK); texture = artifact
		var image: Image = texture.get_image()
		var row: Dictionary = {"name":name,"width":image.get_width(),"height":image.get_height(),"mipmaps":image.has_mipmaps(),"format":image.get_format(),"bytes":image.get_data_size(),"compressed":image.is_compressed()}
		if "android-artifacts" in OS.get_cmdline_user_args(): assert(image.is_compressed() and image.has_mipmaps())
		if image.is_compressed(): assert(image.decompress()==OK)
		if "android-artifacts" in OS.get_cmdline_user_args(): assert(ResourceSaver.save(image,DECODED.path_join(name+"-etc2.res"),ResourceSaver.FLAG_COMPRESS)==OK)
		if "baseline" in OS.get_cmdline_user_args(): assert(image.save_png(folder.path_join(name+".png"))==OK)
		rows.append(row)
	var label: String = "before" if "baseline" in OS.get_cmdline_user_args() else RenderingServer.get_current_rendering_method()
	if "android-artifacts" in OS.get_cmdline_user_args(): label = "android-etc2"
	var output := FileAccess.open(DIRECTORY.path_join(label+".json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(rows,"\t",true)+"\n"); output.close()
	print("GAMEPLAY_TEXTURE_INVENTORY ",label," ",JSON.stringify(rows))
	quit()
