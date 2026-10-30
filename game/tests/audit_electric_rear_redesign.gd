extends SceneTree
## Protect front/roof/wheel buffers while allowing the authorized rear rebuild.
func rear_part(label: String) -> bool:
	for prefix: String in ["Rear","TailOpticEnd","Trunk","CanopyBordertrue","CanopySideFrame","SideGlazing","WindowSill","SculptedSide","ChargingFlap","PlatePocket","PlateBolt","LicensePlate","TailSignature","EndUndertrayRear"]:
		if label.begins_with(prefix): return true
	if label.begins_with("GlassPillar"): return label.contains("0.765")
	if label.begins_with("RolledArch") or label.begins_with("WheelwellTub"):
		return not label.contains("-1.397727")
	return false

func _initialize() -> void:
	var old_root: String="res://assets/vehicles/electric_coachwork_v15"
	var new_root: String="res://assets/vehicles/electric_coachwork_v16"
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(old_root+"/manifest.json"))
	var current: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(new_root+"/manifest.json"))
	var old_parts: Dictionary={}
	var new_parts: Dictionary={}
	for entry: Dictionary in old.meshes: old_parts[entry.part]=entry
	for entry: Dictionary in current.meshes: new_parts[entry.part]=entry
	var exact: int=0
	var changed: Array[String]=[]
	var added: Array[String]=[]
	var removed: Array[String]=[]
	var unexpected: Array[String]=[]
	var front_vertices: int=0
	for entry: Dictionary in current.meshes:
		if not old_parts.has(entry.part):
			added.append(entry.part)
			if not rear_part(entry.part): unexpected.append(entry.part)
			continue
		var a: ArrayMesh=load(old_root.path_join(str(old_parts[entry.part].file)))
		var b: ArrayMesh=load(new_root.path_join(str(entry.file)))
		var same: bool=a.get_surface_count()==b.get_surface_count()
		for i: int in range(a.get_surface_count()): same=same and var_to_bytes(a.surface_get_arrays(i))==var_to_bytes(b.surface_get_arrays(i))
		if same: exact+=1
		else:
			changed.append(entry.part)
			if not rear_part(entry.part): unexpected.append(entry.part)
		if str(entry.part).begins_with("SculptedSide"):
			var aa: Array=a.surface_get_arrays(0)
			var bb: Array=b.surface_get_arrays(0)
			var samples: Dictionary={}
			for i: int in range(aa[Mesh.ARRAY_VERTEX].size()):
				if aa[Mesh.ARRAY_VERTEX][i].z<=1.05: samples[aa[Mesh.ARRAY_TEX_UV][i]]=[aa[Mesh.ARRAY_VERTEX][i],aa[Mesh.ARRAY_NORMAL][i]]
			for i: int in range(bb[Mesh.ARRAY_VERTEX].size()):
				if bb[Mesh.ARRAY_VERTEX][i].z>1.05: continue
				var uv: Vector2=bb[Mesh.ARRAY_TEX_UV][i]
				var value: Array=[bb[Mesh.ARRAY_VERTEX][i],bb[Mesh.ARRAY_NORMAL][i]]
				if not samples.has(uv) or var_to_bytes(samples[uv])!=var_to_bytes(value): unexpected.append(str(entry.part)+" front vertex "+str(uv))
				front_vertices+=1
	for part: String in old_parts:
		if not new_parts.has(part):
			removed.append(part)
			if not rear_part(part): unexpected.append(part)
	var result: Dictionary={"resources_before":old.meshes.size(),"resources_after":current.meshes.size(),"exact_surface_arrays":exact,"changed_rear_arrays":changed,"added_rear_parts":added,"removed_rear_parts":removed,"protected_front_side_vertices":front_vertices,"unexpected_changes":unexpected,"checks":2,"failures":int(not unexpected.is_empty())+int(front_vertices==0)}
	FileAccess.open("res://../docs/evidence/electric-rear-redesign-2026-10-28/prepared-array-audit.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ELECTRIC_REAR_REDESIGN_ARRAYS: ",JSON.stringify({"exact":exact,"front_side_vertices":front_vertices,"unexpected":unexpected.size(),"failures":result.failures}))
	quit(0 if result.failures==0 else 1)
