extends SceneTree
## CI01: small static fittings only; preserve original attributes and boundaries.
const Policy=preload("res://tests/support/car_iteration_policy.gd")
const WORK: String="res://../build/car-iteration-01-2026-11-15"
const OUT: String="res://../docs/evidence/car-iteration-01-2026-11-15"
const Compactor=preload("res://tests/support/car_static_reduction_bake.gd")
var compactor=Compactor.new()
var checks: int=0
var failures: int=0

func protected(row: Dictionary) -> bool:
	if int(row.blend_shapes)>0: return true
	for shader: String in row.shaders:
		if shader!="StandardMaterial3D": return true
	var label: String=str(row.name).to_lower()
	for term: String in ["driver","helmet","glass","seal","roof","pillar","body","coachwork","cabin","arch","skin","hull","deck","canopy","shoulder","hood","bonnet","contour","seam","mirror","lens","light","rearscreen","referencefront","referenceside","referencerear","formedfront","tailrecess"]:
		if term in label: return true
	return false

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var catalog: Dictionary=load(WORK.path_join("survey.res")).get_meta("catalog")
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("survey.json")))
	var refining: bool="--refine" in OS.get_cmdline_user_args()
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("candidate-plan.json"))) if refining else {}
	var review: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("geometry-review.json"))) if refining else {}
	var blocked: Dictionary={};var weights: Dictionary={};var totals: Dictionary={}
	for row: Dictionary in rows:
		if protected(row): blocked[row.key]=true
		if row.mode=="stock":
			weights[row.key]=int(weights.get(row.key,0))+1
			totals[row.vehicle]=int(totals.get(row.vehicle,0))+int(row.triangles)
	var result: Dictionary={};var reductions: Dictionary={}
	var directory: String=WORK.path_join("candidates")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	for key: String in catalog:
		if blocked.has(key): continue
		var entry: Dictionary=catalog[key];var source: Mesh=entry.source
		if refining and entry.vehicle!="forklift": continue
		if refining and review.parts.has(key) and review.parts[key].accepted:
			result[key]=prior.parts[key]
			reductions[entry.vehicle]=int(reductions.get(entry.vehicle,0))+(int(prior.parts[key].before)-int(prior.parts[key].after))*int(weights.get(key,0))
			continue
		if refining and source is CylinderMesh:
			# Exact planar caps: use the boundary vertices instead of a centre fan.
			# The workshop helper supplies indices only; retain the car's GPU bytes.
			var caps: ArrayMesh=preload("res://ui/garage_mesh_cleanup.gd").compact_cylinder_caps(source)
			if caps!=null:
				var packet: Dictionary=RenderingServer.mesh_get_surface(source.get_rid(),0).duplicate(true)
				var indices: PackedInt32Array=caps.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
				var stride: int=2 if int(packet.vertex_count)<=65536 else 4
				var bytes:=PackedByteArray();bytes.resize(indices.size()*stride)
				for at: int in range(indices.size()):
					if stride==2: bytes.encode_u16(at*stride,indices[at])
					else: bytes.encode_u32(at*stride,indices[at])
				packet.index_data=bytes;packet.index_count=indices.size();packet.erase("lods")
				var exact:=ArrayMesh.new();exact.set("_surfaces",[packet]);exact.custom_aabb=source.get_aabb()
				var selected: ArrayMesh=compactor.compact(exact)
				selected.set_meta("car_iteration_source",key);selected.set_meta("car_iteration",1)
				assert(ResourceSaver.save(selected,directory.path_join(key+".res"),ResourceSaver.FLAG_COMPRESS)==OK)
				var before: int=source.get_faces().size()/3;var after: int=indices.size()/3
				result[key]={"vehicle":entry.vehicle,"name":entry.name,"before":before,"after":after,"stock_instances":weights.get(key,0),"exact_caps":true}
				reductions[entry.vehicle]=int(reductions.get(entry.vehicle,0))+(before-after)*int(weights.get(key,0))
				continue
		if source.get_faces().size()/3<40: continue
		var packets: Array=[]
		for at: int in range(source.get_surface_count()): packets.append(RenderingServer.mesh_get_surface(source.get_rid(),at).duplicate(true))
		var before: int=source.get_faces().size()/3
		var after: int=0
		for surface: int in range(source.get_surface_count()):
			var arrays: Array=source.surface_get_arrays(surface)
			var count: int=arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size()
			if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():
				var indices:=PackedInt32Array();indices.resize(count)
				for at: int in range(count): indices[at]=at
				arrays[Mesh.ARRAY_INDEX]=indices
			var tool:=SurfaceTool.new();tool.create_from_arrays(arrays)
			assert(tool.commit_to_arrays()[Mesh.ARRAY_VERTEX]==arrays[Mesh.ARRAY_VERTEX])
			var error: float=0.002 if refining else 0.005 if entry.vehicle in ["forklift","hovercraft"] else 0.01
			var selected: PackedInt32Array=tool.generate_lod(error,int(count*0.60)/3*3)
			var packet: Dictionary=packets[surface]
			packet.erase("lods")
			if selected.is_empty() or selected.size()>=count:
				after+=count/3;continue
			var stride: int=2 if int(packet.vertex_count)<=65536 else 4
			var indices:=PackedByteArray();indices.resize(selected.size()*stride)
			for at: int in range(selected.size()):
				if stride==2: indices.encode_u16(at*stride,selected[at])
				else: indices.encode_u32(at*stride,selected[at])
			packet.index_data=indices;packet.index_count=selected.size()
			after+=selected.size()/3
		if after==before: continue
		var generated:=ArrayMesh.new();generated.set("_surfaces",packets);generated.custom_aabb=source.get_aabb()
		var selected: ArrayMesh=compactor.compact(generated)
		for property: StringName in source.get_meta_list(): selected.set_meta(property,source.get_meta(property))
		selected.set_meta("car_iteration_source",key)
		selected.set_meta("car_iteration",1)
		assert(ResourceSaver.save(selected,directory.path_join(key+".res"),ResourceSaver.FLAG_COMPRESS)==OK)
		result[key]={"vehicle":entry.vehicle,"name":entry.name,"before":before,"after":after,"stock_instances":weights.get(key,0)}
		reductions[entry.vehicle]=int(reductions.get(entry.vehicle,0))+(before-after)*int(weights.get(key,0))
	for id: String in Policy.IDS: print("ITERATION_CANDIDATE ",id," ",totals[id]," -> ",int(totals[id])-int(reductions.get(id,0))," reduction=",float(reductions.get(id,0))/float(totals[id])*100.0)
	FileAccess.open(OUT.path_join("candidate-plan.json"),FileAccess.WRITE).store_string(JSON.stringify({"parts":result,"before":totals,"reductions":reductions,"blocked_keys":blocked.keys()},"  "))
	print("ITERATION_CANDIDATES ",result.size()," isolated static fittings")
	quit()
