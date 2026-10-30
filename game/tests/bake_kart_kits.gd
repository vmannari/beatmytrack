extends SceneTree
## Add immutable per-part meshes without rewriting historical stock mesh files.
const G = preload("res://vehicle/kart_geometry.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var path: String = G.ROOT.path_join("manifest.json")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var entries: Dictionary = {}
	for entry: Dictionary in manifest.meshes: entries[entry.key] = entry
	for simple: bool in [false,true]:
		for category: String in VehicleCustomisation.CATEGORIES:
			for option: Array in VehicleCustomisation.options(category,"kart"):
				var car := CarVisual.new()
				car.vehicle_id = "kart"
				car.simple_model = simple
				car.batch_parts = false
				car.customisation = VehicleCustomisation.defaults()
				car.customisation[category] = option[0]
				root.add_child(car)
				while not car.model_ready: await process_frame
				car.free()
	var added: int = 0
	for key: String in G.meshes:
		var filename: String = key.sha256_text().left(24)+".res"
		var target: String = G.ROOT.path_join(filename)
		if not ResourceLoader.exists(target):
			assert(ResourceSaver.save(G.meshes[key],target,ResourceSaver.FLAG_COMPRESS)==OK)
			added += 1
		entries[key] = {"key":key,"file":filename,"triangles":G.meshes[key].get_faces().size()/3}
	manifest.meshes = entries.values()
	for source: String in ["model","detail","kits","kit_shapes"]:
		manifest[source+"_sha256"] = FileAccess.get_sha256("res://vehicle/kart_"+source+".gd")
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	print("KART_KIT_BAKE: ",added," added meshes; ",entries.size()," total; stock resources retained")
	quit()
