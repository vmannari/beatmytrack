extends SceneTree
func _initialize() -> void:
	var old_root := "res://assets/vehicles/electric_subtle_fenders_v1"
	var new_root := "res://assets/vehicles/electric_curved_rear_window_v1"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(new_root.path_join("manifest.json")))
	var result: Dictionary = {"exact":[],"changed":[],"count":manifest.meshes.size(),"unexpected":[]}
	for entry: Dictionary in manifest.meshes:
		var old_mesh: ArrayMesh = load(old_root.path_join(entry.file))
		var new_mesh: ArrayMesh = load(new_root.path_join(entry.file))
		var same: bool = old_mesh.get_surface_count()==new_mesh.get_surface_count()
		for index: int in new_mesh.get_surface_count():
			same = same and var_to_bytes(old_mesh.surface_get_arrays(index))==var_to_bytes(new_mesh.surface_get_arrays(index))
		if same: result.exact.append(entry.part)
		else: result.changed.append(entry.part)
		if not same and str(entry.part).trim_suffix("_simple") not in ["ReferenceRearDeck","ReferenceRearScreen","ReferenceRoofRail0","ReferenceRoofRail1","SportDeckLip"]:
			result.unexpected.append(entry.part)
	FileAccess.open("res://../docs/evidence/volt-curved-rear-window-2026-10-31/prepared-array-comparison.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("PREPARED_ARRAY_COMPARISON: ",result.count," meshes, ",result.exact.size()," exact; changed=",result.changed," unexpected=",result.unexpected)
	quit(0 if result.unexpected.is_empty() else 1)
