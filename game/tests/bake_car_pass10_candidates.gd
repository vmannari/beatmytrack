extends SceneTree
const WORK: String="res://../build/car-pass10-2026-11-16"
const OUT: String="res://../docs/evidence/car-pass10-2026-11-16"
var compactor=preload("res://tests/support/car_static_reduction_bake.gd").new()

func protected(row: Dictionary) -> bool:
	if int(row.blend_shapes)>0 or "Driver" in str(row.path): return true
	for shader: String in row.shaders:
		if shader!="StandardMaterial3D": return true
	var label: String=str(row.name).to_lower()
	for term: String in ["helmet","glass","glazing","seal","roof","pillar","window","cabin","arch","contour","seam","mirror","lamp","lens","optical","canopy"]:
		if term in label: return true
	return false

func _initialize() -> void:
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var observations: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("survey.json")))
	var blocked: Dictionary={};
	for key: String in JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("candidate-plan.json"))).blocked_keys:blocked[key]=true
	var weights: Dictionary={};var scales: Dictionary={};var totals: Dictionary={}
	for row: Dictionary in observations:
		pass # Protection is bound by the current task survey, including the repaired fascia.
		scales[row.key]=maxf(float(scales.get(row.key,0)),float(row.maximum_scale))
		if row.mode=="stock":
			weights[row.key]=int(weights.get(row.key,0))+1
			totals[row.vehicle]=int(totals.get(row.vehicle,0))+int(row.triangles)
	var parts: Dictionary={};var savings: Dictionary={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("candidates")))
	for key: String in catalog:
		if blocked.has(key): continue
		var entry: Dictionary=catalog[key];var source: Mesh=entry.source
		if source.has_meta("car_surface_guide_locked"): continue
		var before: int=source.get_faces().size()/3
		var caps: ArrayMesh=preload("res://ui/garage_mesh_cleanup.gd").compact_cylinder_caps(source) if source is CylinderMesh else null
		if before<8 or not weights.has(key): continue
		var packets: Array=[];var after: int=0
		for surface: int in range(source.get_surface_count()):
			var packet: Dictionary=RenderingServer.mesh_get_surface(source.get_rid(),surface).duplicate(true)
			packet.aabb=source.get_aabb();packet.erase("lods")
			var arrays: Array=source.surface_get_arrays(surface)
			var count: int=arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
			if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():
				var indices:=PackedInt32Array();indices.resize(count)
				for at: int in range(count): indices[at]=at
				arrays[Mesh.ARRAY_INDEX]=indices
			var selected: PackedInt32Array
			if caps!=null: selected=caps.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
			else:
				var tool:=SurfaceTool.new();tool.create_from_arrays(arrays)
				assert(tool.commit_to_arrays()[Mesh.ARRAY_VERTEX]==arrays[Mesh.ARRAY_VERTEX])
				selected=tool.generate_lod(0.003,int(count*0.50)/3*3)
			if not selected.is_empty() and selected.size()<count:
				var stride: int=2 if int(packet.vertex_count)<=65536 else 4
				var bytes:=PackedByteArray();bytes.resize(selected.size()*stride)
				for at: int in range(selected.size()):
					if stride==2: bytes.encode_u16(at*stride,selected[at])
					else: bytes.encode_u32(at*stride,selected[at])
				packet.index_data=bytes;packet.index_count=selected.size();packet.format=int(packet.format)|Mesh.ARRAY_FORMAT_INDEX
				after+=selected.size()/3
			else: after+=count/3
			packets.append(packet)
		if before==after: continue
		var raw:=ArrayMesh.new();raw.set("_surfaces",packets);raw.custom_aabb=source.get_aabb()
		var selected: ArrayMesh=compactor.compact(raw)
		for property: StringName in source.get_meta_list(): selected.set_meta(property,source.get_meta(property))
		selected.set_meta("car_pass10_source",key)
		var file: String=key+"_lod.res"
		assert(ResourceSaver.save(selected,WORK.path_join("candidates").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		parts[key]={"vehicle":entry.vehicle,"name":entry.name,"before":before,"after":after,"stock_instances":weights.get(key,0),"maximum_scale":scales[key],"file":file,"resource":entry.resource,"exact_caps":caps!=null}
		savings[entry.vehicle]=int(savings.get(entry.vehicle,0))+(before-after)*int(weights.get(key,0))
	FileAccess.open(OUT.path_join("candidate-plan.json"),FileAccess.WRITE).store_string(JSON.stringify({"parts":parts,"before":totals,"reductions":savings,"blocked_keys":blocked.keys()},"  "))
	for id: String in totals: print("CAR15_CANDIDATE ",id," ",totals[id]," -> ",int(totals[id])-int(savings.get(id,0)))
	print("CAR15_CANDIDATES ",parts.size());quit()
