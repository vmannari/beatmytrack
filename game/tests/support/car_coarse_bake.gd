extends "res://tests/support/car_static_reduction_bake.gd"
## CCG01: shared coarse policy for source construction and fitted modules.
const Coarse = preload("res://vehicle/car_coarse_reduction.gd")

func create_coarse(part: MeshInstance3D, car: CarVisual) -> Mesh:
	var source: ArrayMesh = part.mesh
	if not lods.eligible(part,car.vehicle_id) or source.has_meta("car_authored_far"): return source
	var budget: float = Coarse.METRIC
	var code: String = car.vehicle_id+"_"+Coarse.key(source,budget)
	if saved.has(code): return saved[code]
	var generated: Mesh = lods.prepare(source)
	var packets: Array = source.get("_surfaces").duplicate(true)
	var changed: bool = false
	for surface: int in range(packets.size()):
		var packet: Dictionary = packets[surface]
		var chosen: PackedByteArray = packet.get("index_data",PackedByteArray())
		var stride: int = 2 if int(packet.vertex_count)<=65536 else 4
		var levels: Array = generated.get("_surfaces")[surface].get("lods",[])
		for at: int in range(0,levels.size(),2):
			if float(levels[at])<=budget and levels[at+1].size()<chosen.size(): chosen=levels[at+1]
		packet.erase("lods")
		if not chosen.is_empty() and chosen.size()/stride<int(packet.get("index_count",0)):
			packet.index_data=chosen
			packet.index_count=chosen.size()/stride
			changed=true
	if not changed:
		saved[code]=source
		return source
	var selected := ArrayMesh.new()
	selected.set("_surfaces",packets)
	selected.custom_aabb=source.get_aabb()
	selected.shadow_mesh=source.shadow_mesh
	var result: ArrayMesh = compact(selected)
	for property: StringName in source.get_meta_list(): result.set_meta(property,source.get_meta(property))
	result.set_meta("car_coarse_source",Coarse.key(source,budget))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Coarse.ROOT))
	var path: String = Coarse.ROOT.path_join(code+".res")
	assert(ResourceSaver.save(result,path,ResourceSaver.FLAG_COMPRESS)==OK)
	saved[code]=result
	observations.append({"vehicle":car.vehicle_id,"part":str(part.name),"path":path,"metric":budget,"before":source.get_faces().size()/3,"after":result.get_faces().size()/3})
	return result
