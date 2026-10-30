extends SceneTree
## Compare actual immutable prepared buffers and measure the relocated glazing.
func _initialize() -> void:
	var previous: String="res://assets/vehicles/electric_coachwork_v16"
	var current: String="res://assets/vehicles/electric_coachwork_v17"
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(previous+"/manifest.json"))
	var next: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(current+"/manifest.json"))
	var parts: Dictionary={}
	for entry: Dictionary in old.meshes: parts[entry.part]=entry
	var exact: int=0
	var changed: Array[String]=[]
	var unexpected: Array[String]=[]
	var windows: Dictionary={}
	var allowed: Array[String]=["CrownedRoof","RearScreen","CanopyBordertrue","CanopySideFrame","SideGlazing","GlassPillar","WindowSill","TrunkSideApron"]
	for entry: Dictionary in next.meshes:
		var a: ArrayMesh=load(previous.path_join(str(parts[entry.part].file)))
		var b: ArrayMesh=load(current.path_join(str(entry.file)))
		var same: bool=a.get_surface_count()==b.get_surface_count()
		for i: int in range(a.get_surface_count()): same=same and var_to_bytes(a.surface_get_arrays(i))==var_to_bytes(b.surface_get_arrays(i))
		if same: exact+=1
		else:
			changed.append(entry.part)
			var permitted: bool=false
			for prefix: String in allowed: permitted=permitted or str(entry.part).begins_with(prefix)
			if not permitted: unexpected.append(entry.part)
		if str(entry.part).begins_with("RearScreen"):
			var before: AABB=a.get_aabb()
			var after: AABB=b.get_aabb()
			windows[entry.part]={"before_z_model_metres":[before.position.z,before.end.z],"after_z_model_metres":[after.position.z,after.end.z],"front_edge_shift_world_metres":(after.position.z-before.position.z)*HandlingConfig.BODY_SCALE,"back_edge_shift_world_metres":(after.end.z-before.end.z)*HandlingConfig.BODY_SCALE,"after_deck_clearance_model_metres":1.78-after.end.z}
	var failures: int=int(next.meshes.size()!=old.meshes.size())+int(not unexpected.is_empty())
	var result: Dictionary={"prepared_resources":next.meshes.size(),"exact_surface_arrays":exact,"changed_arrays":changed,"unexpected_changes":unexpected,"windows":windows,"failures":failures}
	FileAccess.open("res://../docs/evidence/volt-rear-window-back-2026-10-28/array-audit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("VOLT_WINDOW_AUDIT: ",JSON.stringify(result))
	quit(0 if failures==0 else 1)
