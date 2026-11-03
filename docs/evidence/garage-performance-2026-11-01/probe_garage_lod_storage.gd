extends SceneTree
func _initialize() -> void:
	var scene: PackedScene = load(GarageEnvironment.PREPARED_ARCHITECTURE)
	var holder: Node = scene.instantiate()
	for part: Node in holder.find_children("*","MeshInstance3D",true,false):
		if not part.mesh is ArrayMesh: continue
		var surfaces: Array = part.mesh.get("_surfaces")
		for surface: Dictionary in surfaces:
			if surface.has("lods"):
				print("LOD_KEYS ",surface.keys())
				print("LOD_STORAGE ",var_to_str(surface.lods).left(800))
				print("LOD_VERTEX_COUNT ",surface.get("vertex_count")," ",surface.get("index_count"))
				var copy := ArrayMesh.new()
				copy.set("_surfaces",surfaces)
				print("RAW_COPY_EXACT ",copy.surface_get_arrays(0)==part.mesh.surface_get_arrays(0))
				holder.free()
				quit(); return
	holder.free()
	quit(1)
