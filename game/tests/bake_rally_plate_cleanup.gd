extends SceneTree
## Rebuild only the shared Rally plate meshes; preserve unrelated kit resources.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	CompactKits.use_baked = false
	var material := StandardMaterial3D.new()
	for simple: bool in [false, true]:
		CompactKits.simple_parts = simple
		for kind: String in CompactBodyKits.PROFILES:
			var holder := Node3D.new()
			CompactBodyKits.build(holder, kind, material, material, material)
			holder.free()
		for kind: String in CompactAero.PROFILES:
			var holder := Node3D.new()
			CompactAero.build(holder, kind, material, material, material)
			holder.free()
	var path: String = CompactKits.ASSET_ROOT.path_join("manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var count: int = 0
	for key: String in CompactKits.meshes:
		if not key.contains("/plate2"): continue
		var mesh: ArrayMesh = CompactKits.meshes[key]
		var target: String = CompactKits.ASSET_ROOT.path_join("meshes/"+key.sha256_text()+".res")
		assert(ResourceSaver.save(mesh,target,ResourceSaver.FLAG_COMPRESS)==OK)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(var_to_bytes(mesh.surface_get_arrays(0)))
		manifest.meshes[key] = {"file":target.get_file(),"surface_sha256":digest.finish().hex_encode()}
		count += 1
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	print("RALLY_PLATE_BAKE: ",count," meshes")
	quit()
