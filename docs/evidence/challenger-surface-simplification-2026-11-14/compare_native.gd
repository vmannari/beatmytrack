extends SceneTree
func _initialize() -> void:
	var checks: int = 0
	var differences: Array[String] = []
	var candidate: String = "res://../build/challenger-surface-simplification-2026-11-14/native/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SuperRallyModel.ROOT+"manifest.json"))
	for tier: String in ["full","simple"]:
		for entry: Dictionary in manifest.tiers[tier]:
			var name: String = str(entry.mesh)
			var live_path: String = SuperRallyModel.ROOT+name
			var private_path: String = candidate+name
			var uid: int = ResourceLoader.get_resource_uid(live_path)
			if uid != ResourceUID.INVALID_ID: assert(ResourceSaver.set_uid(private_path,uid) == OK)
			if name.ends_with("_body_paint.res") or name.ends_with("_body_contour.res"): continue
			var a: Mesh = load(live_path)
			var b: Mesh = load(private_path)
			checks += 1
			if a.get_aabb() != b.get_aabb(): differences.append(name+" bounds")
			checks += 1
			if a.get_surface_count() != b.get_surface_count(): differences.append(name+" surface count")
			for surface: int in range(a.get_surface_count()):
				checks += 1
				if a.surface_get_arrays(surface) != b.surface_get_arrays(surface): differences.append(name+" arrays "+str(surface))
	var file := FileAccess.open("res://../docs/evidence/challenger-surface-simplification-2026-11-14/native-comparison.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":differences.size(),"findings":differences,"valid_live_uids_preserved":true},"\t"));file.close()
	print("NATIVE_UNCHANGED_PARTS: ",checks," checks, ",differences.size()," failures")
	for finding: String in differences: print(finding)
	quit(0 if differences.is_empty() else 1)
