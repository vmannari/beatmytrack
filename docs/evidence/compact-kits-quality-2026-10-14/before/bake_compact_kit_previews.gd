extends SceneTree
## Offline original-model photographs and immutable authored part meshes.
const ASSET_ROOT: String = "res://assets/vehicles/compact_kits_v1"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var renderer: String = RenderingServer.get_current_rendering_method()
	var directory: String = ASSET_ROOT.path_join("previews/"+renderer)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ASSET_ROOT.path_join("meshes")))
	CompactKits.use_baked = false
	preload("res://vehicle/prepared_car_cache.gd").enabled = false
	CompactKits.meshes.clear()
	CompactKitThumbnail.use_prepared = false
	CompactKitThumbnail.images.clear()
	var aero_only: bool = "--aero-only" in OS.get_cmdline_user_args()
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ASSET_ROOT.path_join("manifest.json")))
	var photo_count: int = 0
	for category: String in VehicleCustomisation.CATEGORIES:
		if aero_only and category!="aero": continue
		for option: Array in VehicleCustomisation.OPTIONS[category]:
			var photo: CompactKitThumbnail = CompactKitThumbnail.make(category,option,false,func() -> void: pass)
			root.add_child(photo)
			for frame: int in range(6):
				await process_frame
				await RenderingServer.frame_post_draw
			var pixels: Image = photo.image.texture.get_image()
			var path: String = directory.path_join(category+"_"+str(option[0])+".png")
			if pixels.save_png(path)!=OK:
				push_error("Cannot save kit preview: "+path)
				quit(1)
				return
			photo.queue_free()
			await process_frame
			photo_count += 1
	# Both authored sampling levels have the exact same immutable source cache.
	for category: String in VehicleCustomisation.CATEGORIES:
		if aero_only and category!="aero": continue
		for option: Array in VehicleCustomisation.OPTIONS[category]:
			var car := CarVisual.new()
			car.simple_model = true
			car.customisation = VehicleCustomisation.defaults()
			car.customisation[category] = option[0]
			root.add_child(car)
			car.queue_free()
			await process_frame
	var manifest: Dictionary = {}
	if aero_only:
		for key: String in original.meshes:
			if not key.begins_with("aero/") and not key.begins_with("aero4/"): manifest[key] = original.meshes[key]
	for key: String in CompactKits.meshes:
		var path: String = ASSET_ROOT.path_join("meshes/"+key.sha256_text()+".res")
		var mesh: ArrayMesh = CompactKits.meshes[key]
		if ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)!=OK:
			push_error("Cannot save kit mesh "+key)
			quit(1)
			return
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(var_to_bytes(mesh.surface_get_arrays(0)))
		manifest[key] = {"file":path.get_file(),"surface_sha256":digest.finish().hex_encode()}
	var file := FileAccess.open(ASSET_ROOT.path_join("manifest.json"),FileAccess.WRITE)
	var counts: Dictionary = {}
	for category: String in VehicleCustomisation.CATEGORIES: counts[category] = VehicleCustomisation.OPTIONS[category].size()
	file.store_string(JSON.stringify({"version":3,"category_counts":counts,"meshes":manifest},"\t"))
	file.close()
	# Retire only obsolete generated mesh files named by the previous manifest.
	var mesh_directory: String = ProjectSettings.globalize_path(ASSET_ROOT.path_join("meshes"))
	for key: String in original.meshes:
		if manifest.has(key): continue
		var filename: String = str(original.meshes[key].file)
		var target: String = mesh_directory.path_join(filename)
		assert(filename==filename.get_file() and filename.ends_with(".res") and target.get_base_dir()==mesh_directory)
		if DirAccess.remove_absolute(target)!=OK: push_warning("Obsolete prepared mesh could not be removed: "+filename)
	print("KIT_BAKE: ",photo_count," ",renderer," previews; ",manifest.size()," immutable meshes")
	quit()
