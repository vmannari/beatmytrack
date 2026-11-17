extends SceneTree
const WORK: String="res://../build/car-pass12-2026-11-16"
const OUT: String="res://../docs/evidence/car-pass12-2026-11-16"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("candidates")))
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var plan: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("candidate-plan.json")))
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(WORK.path_join("radial-remeshed.json")))
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("survey.json")))
	var weights: Dictionary={};var scales: Dictionary={}
	for row: Dictionary in rows:
		if row.mode=="stock": weights[row.key]=int(weights.get(row.key,0))+1
		scales[row.key]=maxf(float(scales.get(row.key,0)),float(row.maximum_scale))
	var parts: Dictionary={}
	for key: String in data:
		var original_key: String=key.get_slice("@",0)
		var source: Mesh=catalog[original_key].source
		var output:=ArrayMesh.new();var witnesses: Array=[];var contacts: Array=[]
		var before: int=source.get_faces().size()/3;var after: int=0
		for surface: int in range(source.get_surface_count()):
			var entry: Variant=data[key][surface]
			if entry==null:
				output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(surface))
				witnesses.append([]);contacts.append([]);after+=source.surface_get_arrays(surface)[Mesh.ARRAY_INDEX].size()/3
				continue
			var positions:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array();var uv2:=PackedVector2Array();var colors:=PackedColorArray();var tangents:=PackedFloat32Array();var indices:=PackedInt32Array()
			var records: Dictionary={};var references: Array=[]
			for at: int in entry.indices:
				var p:=Vector3(entry.vertices[at][0],entry.vertices[at][1],entry.vertices[at][2]);var n:=Vector3(entry.normals[at][0],entry.normals[at][1],entry.normals[at][2])
				var record: Array=[p,n,Vector2(entry.uv[at][0],entry.uv[at][1]) if not entry.uv.is_empty() else Vector2.ZERO,Vector2(entry.uv2[at][0],entry.uv2[at][1]) if not entry.uv2.is_empty() else Vector2.ZERO,Color(entry.colors[at][0],entry.colors[at][1],entry.colors[at][2],entry.colors[at][3]) if not entry.colors.is_empty() else Color.WHITE,PackedFloat32Array(entry.tangents.slice(at*4,at*4+4)) if not entry.tangents.is_empty() else PackedFloat32Array()]
				var code: String=var_to_bytes(record).hex_encode()
				if not records.has(code):
					records[code]=positions.size();positions.append(p);normals.append(n);references.append(entry.witnesses[at])
					if not entry.uv.is_empty(): uv.append(Vector2(entry.uv[at][0],entry.uv[at][1]))
					if not entry.uv2.is_empty(): uv2.append(Vector2(entry.uv2[at][0],entry.uv2[at][1]))
					if not entry.colors.is_empty(): colors.append(Color(entry.colors[at][0],entry.colors[at][1],entry.colors[at][2],entry.colors[at][3]))
					if not entry.tangents.is_empty(): tangents.append_array(PackedFloat32Array(entry.tangents.slice(at*4,at*4+4)))
				indices.append(records[code])
			var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=positions;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_INDEX]=indices
			if not uv.is_empty(): arrays[Mesh.ARRAY_TEX_UV]=uv
			if not uv2.is_empty(): arrays[Mesh.ARRAY_TEX_UV2]=uv2
			if not colors.is_empty(): arrays[Mesh.ARRAY_COLOR]=colors
			if not tangents.is_empty(): arrays[Mesh.ARRAY_TANGENT]=tangents
			output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			witnesses.append(references);contacts.append(entry.contact_vertices);after+=indices.size()/3
		if after>=before: continue
		var packets: Array=output.get("_surfaces")
		for packet: Dictionary in packets: packet.aabb=source.get_aabb()
		var result:=ArrayMesh.new();result.set("_surfaces",packets);result.custom_aabb=source.get_aabb()
		for property: StringName in source.get_meta_list(): result.set_meta(property,source.get_meta(property))
		result.set_meta("car_pass12_source",original_key);result.set_meta("car_pass12_witnesses",witnesses);result.set_meta("car_pass12_contacts",contacts)
		var file: String=key+"_radial.res"
		assert(ResourceSaver.save(result,WORK.path_join("candidates").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		parts[key+"_projected"]={"source_key":original_key,"vehicle":catalog[original_key].vehicle,"name":catalog[original_key].name,"before":before,"after":after,"stock_instances":weights[original_key],"maximum_scale":scales[original_key],"file":file,"resource":catalog[original_key].resource,"kind":"projected"}
	plan.parts=parts
	FileAccess.open(OUT.path_join("candidate-plan.json"),FileAccess.WRITE).store_string(JSON.stringify(plan,"  "))
	print("CAR15_PROJECTED ",parts.size());quit()
