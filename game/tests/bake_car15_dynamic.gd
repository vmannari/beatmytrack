extends SceneTree
const WORK: String="res://../build/car15-2026-11-15"
const OUT: String="res://../docs/evidence/car15-2026-11-15"
func _initialize() -> void:
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("candidate-plan.json")))
	var blocked: Dictionary={}
	for key: String in old.blocked_keys: blocked[key]=true
	var observations: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("survey.json")))
	var weights: Dictionary={};var scales: Dictionary={}
	for row: Dictionary in observations:
		if row.mode=="stock": weights[row.key]=int(weights.get(row.key,0))+1
		scales[row.key]=maxf(float(scales.get(row.key,0)),float(row.maximum_scale))
	var compactor=preload("res://tests/support/car_static_reduction_bake.gd").new()
	var parts: Dictionary={}
	for key: String in catalog:
		if blocked.has(key): continue
		var entry: Dictionary=catalog[key];var source: Mesh=entry.source
		if source.has_meta("car_surface_guide_locked"): continue
		if "plate" in str(entry.name).to_lower() or "letter" in str(entry.name).to_lower(): continue
		var before: int=source.get_faces().size()/3
		if before<24: continue
		var packets: Array=[];var after: int=0
		for surface: int in range(source.get_surface_count()):
			var arrays: Array=source.surface_get_arrays(surface)
			var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
			var original: PackedInt32Array=arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
			if original.is_empty():
				for at: int in range(positions.size()): original.append(at)
			var identities: Dictionary={};var unique:=PackedVector3Array();var remap:=PackedInt32Array();var aliases: Array=[]
			for at: int in range(positions.size()):
				var point: Vector3=positions[at].snapped(Vector3.ONE*0.0000001)
				if not identities.has(point): identities[point]=unique.size();unique.append(positions[at]);aliases.append([])
				var one: int=identities[point];remap.append(one);aliases[one].append(at)
			var indices:=PackedInt32Array()
			for at: int in original: indices.append(remap[at])
			var solver: Array=[];solver.resize(Mesh.ARRAY_MAX);solver[Mesh.ARRAY_VERTEX]=unique;solver[Mesh.ARRAY_INDEX]=indices
			var tool:=SurfaceTool.new();tool.create_from_arrays(solver)
			var selected: PackedInt32Array=tool.generate_lod(clampf(0.001/maxf(0.001,source.get_aabb().size.length()*float(scales[key])),0.00001,0.2),maxi(12,int(original.size()*0.30)/3*3))
			var mapped:=PackedInt32Array()
			for at: int in range(0,selected.size(),3):
				var normal: Vector3=-(unique[selected[at+1]]-unique[selected[at]]).cross(unique[selected[at+2]]-unique[selected[at]]).normalized()
				for corner: int in range(3):
					var options: Array=aliases[selected[at+corner]]
					var choice: int=options[0];var score: float=-INF
					for option: int in options:
						var value: float=normals[option].dot(normal) if normals.size()==positions.size() else 0.0
						if value>score: score=value;choice=option
					mapped.append(choice)
			var packet: Dictionary=RenderingServer.mesh_get_surface(source.get_rid(),surface).duplicate(true);packet.erase("lods");packet.aabb=source.get_aabb()
			if not mapped.is_empty() and mapped.size()<original.size():
				var stride: int=2 if int(packet.vertex_count)<=65536 else 4
				var bytes:=PackedByteArray();bytes.resize(mapped.size()*stride)
				for at: int in range(mapped.size()):
					if stride==2: bytes.encode_u16(at*stride,mapped[at])
					else: bytes.encode_u32(at*stride,mapped[at])
				packet.index_data=bytes;packet.index_count=mapped.size();packet.format=int(packet.format)|Mesh.ARRAY_FORMAT_INDEX
				after+=mapped.size()/3
			else: after+=original.size()/3
			packets.append(packet)
		if after==before: continue
		var raw:=ArrayMesh.new();raw.set("_surfaces",packets);raw.custom_aabb=source.get_aabb()
		var result: ArrayMesh=compactor.compact(raw)
		for property: StringName in source.get_meta_list(): result.set_meta(property,source.get_meta(property))
		result.set_meta("car15_source",key)
		var file: String=key+"_dynamic.res"
		assert(ResourceSaver.save(result,WORK.path_join("candidates").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		parts[key+"_dynamic"]={"source_key":key,"vehicle":entry.vehicle,"name":entry.name,"before":before,"after":after,"stock_instances":weights.get(key,0),"maximum_scale":scales[key],"file":file,"resource":entry.resource,"kind":"dynamic"}
	old.parts=parts
	FileAccess.open(OUT.path_join("candidate-plan.json"),FileAccess.WRITE).store_string(JSON.stringify(old,"  "))
	print("CAR15_WELDED ",parts.size());quit()
