extends SceneTree
## Semantic buffer audit: serialized resource paths differ across versions.
func _initialize() -> void:
	var old_root: String="res://assets/vehicles/electric_coachwork_v14"
	var new_root: String="res://assets/vehicles/electric_coachwork_v15"
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(old_root+"/manifest.json"))
	var current: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(new_root+"/manifest.json"))
	var old_parts: Dictionary={}
	for entry: Dictionary in old.meshes: old_parts[entry.part]=entry
	var allowed: Array[String]=["RearDeck","TrunkShutline","CanopyBordertrue","RearScreen","CanopySideFrame","SideGlazing","WindowSill"]
	var exact: Array[String]=[]
	var changed: Array[String]=[]
	var unexpected: Array[String]=[]
	for entry: Dictionary in current.meshes:
		assert(old_parts.has(entry.part))
		var a: ArrayMesh=load(old_root.path_join(str(old_parts[entry.part].file)))
		var b: ArrayMesh=load(new_root.path_join(str(entry.file)))
		var same: bool=a.get_surface_count()==b.get_surface_count()
		for i: int in range(a.get_surface_count()):
			same=same and var_to_bytes(a.surface_get_arrays(i))==var_to_bytes(b.surface_get_arrays(i))
		if same: exact.append(entry.part)
		else:
			changed.append(entry.part)
			var permitted: bool=false
			for prefix: String in allowed: permitted=permitted or str(entry.part).begins_with(prefix)
			if not permitted: unexpected.append(entry.part)
	var result: Dictionary={"resources":current.meshes.size(),"exact_surface_arrays":exact.size(),"changed_rear_arrays":changed,"unexpected_changes":unexpected,"original_front_roof_wheels_fascia_buffers_preserved":unexpected.is_empty(),"checks":2,"failures":int(current.meshes.size()!=old.meshes.size())+int(not unexpected.is_empty())}
	FileAccess.open("res://../docs/evidence/electric-rear-flow-2026-10-28/prepared-array-audit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ELECTRIC_REAR_ARRAYS: ",JSON.stringify(result))
	quit(0 if result.failures==0 else 1)
