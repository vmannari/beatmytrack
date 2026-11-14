extends "res://tests/review_model_refinement_metrics.gd"
## Production reduction, encoded attributes, canonical controls and cache hits.
const DEST = "res://../docs/evidence/car-simplification-2026-11-13"
const R = preload("res://vehicle/car_static_reduction.gd")

func _initialize() -> void: verify.call_deferred()

func vertex_codes(mesh: ArrayMesh, surface: int, only_referenced: bool) -> Dictionary:
	var packet: Dictionary = mesh.get("_surfaces")[surface]
	var count: int = packet.vertex_count
	var format: int = mesh.surface_get_format(surface)
	var ps: int = RenderingServer.mesh_surface_get_format_vertex_stride(format,count)
	var ns: int = RenderingServer.mesh_surface_get_format_normal_tangent_stride(format,count)
	var ats: int = RenderingServer.mesh_surface_get_format_attribute_stride(format,count)
	var raw: PackedByteArray = packet.vertex_data
	var attrs: PackedByteArray = packet.get("attribute_data",PackedByteArray())
	var indices: PackedByteArray = packet.get("index_data",PackedByteArray())
	var used: Dictionary = {}
	if only_referenced and not indices.is_empty():
		var stride: int = indices.size()/int(packet.index_count)
		for offset: int in range(0,indices.size(),stride): used[indices.decode_u16(offset) if stride==2 else indices.decode_u32(offset)]=true
	else:
		for index: int in range(count): used[index]=true
	var result: Dictionary = {}
	for index: int in used:
		var code: PackedByteArray = raw.slice(index*ps,(index+1)*ps)
		if ns: code.append_array(raw.slice(count*ps+index*ns,count*ps+(index+1)*ns))
		if ats: code.append_array(attrs.slice(index*ats,(index+1)*ats))
		result[code]=true
	return result

func verify_piece(node: MeshInstance3D, id: String) -> Mesh:
	var source: ArrayMesh = node.mesh
	var result: ArrayMesh = R.resolve(source,id)
	if result==source: return source
	check(result.get_surface_count()==source.get_surface_count(),"same material slots "+id+str(node.name))
	check(result.get_aabb()==source.get_aabb(),"same culling bounds "+id+str(node.name))
	for surface: int in range(source.get_surface_count()):
		var reference: Dictionary = vertex_codes(source,surface,false)
		var retained: Dictionary = vertex_codes(result,surface,true)
		var exact: bool = true
		for code: PackedByteArray in retained: exact=exact and reference.has(code)
		check(exact,"retained encoded positions/normals/UVs "+id+str(node.name)+str(surface))
	return result

func verify() -> void:
	var start: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEST+"/start.json"))
	for file: String in start:
		if file.begins_with("game/resources/cars/") or file in [".git/index","game/vehicle/kart_steering.gd","game/vehicle/kart_model.gd","game/vehicle/forklift_model.gd","game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/driver.res","game/assets/vehicles/kart_refined_v1/tomkart_driver_v1/helmet_static.res"]:
			check(FileAccess.get_sha256("res://../"+file)==start[file],"exact canonical/driver source "+file)
	check("super_rally" not in R.IDS,"Challenger excluded from static reduction")
	var probe := Node3D.new()
	var part := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.rings=4
	cylinder.radial_segments=12
	part.mesh=cylinder
	probe.add_child(part)
	RacingCarModels._reduce_primitives(probe)
	check(part.mesh.rings==4,"default reducer retains excluded-car axial sampling")
	probe.free()
	var prepared: bool = "--prepared" in OS.get_cmdline_user_args()
	var original_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DEST+"/baseline-metrics/headless.json"))
	preload("res://ui/garage_car_cache.gd").enabled=false
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		Base.enabled=prepared
		Kits.enabled=prepared
		Cache.enabled=prepared
		Cache.entries.clear()
		R.enabled=true
		R.offline=Callable() if prepared else verify_piece
		var car := CarVisual.new()
		car.vehicle_id=id
		car.cache_rest_pose=false
		car.livery=VehicleLivery.defaults(id)
		var before_hits: int = Base.hits
		root.add_child(car)
		while not car.model_ready: await process_frame
		if prepared: check(Base.hits==before_hits+1,"actual prepared-base hit "+id)
		var data: Dictionary = inventory(car,false)
		var prior: Dictionary = {}
		for row: Dictionary in original_data.rows:
			if row.id==id and row.case==0: prior=row
		check(data.surfaces==prior.surfaces+(1 if id=="kart" else 0),"retained surface budget plus static Kart suit "+id)
		check(data.triangles<int(prior.triangles) if id!="hovercraft" else data.triangles==int(prior.triangles),"stock master geometry budget "+id)
		if id=="compact":
			check(car.find_child("DoorSeamsLeft",true,false)!=null and car.find_child("DoorSeamsRight",true,false)!=null and car.find_child("TailgatePanelSeam",true,false)!=null,"three Rally contour attachment groups survive batching")
		if id=="kart":
			var driver: MeshInstance3D = car.find_child("TomkartDriver",true,false)
			check(driver.mesh.get_blend_shape_count()==10,"all ten driver poses retained")
			var fixed: MeshInstance3D = driver.find_child("DriverStaticSuit",true,false)
			check(fixed!=null and driver.mesh.get_faces().size()/3+fixed.mesh.get_faces().size()/3==6456,"animated and static cloth/glove topology retained")
			var helmet: MeshInstance3D = car.find_child("HelmetStatic",true,false)
			check(helmet.mesh.get_faces().size()/3==3492,"reduced static helmet")
		if id=="hovercraft":
			var found: bool = false
			for node: MeshInstance3D in car.find_children("*","MeshInstance3D",true,false):
				if not node.mesh.has_meta("car_authored_far"): continue
				found=true
				var packet: Dictionary = node.mesh.get("_surfaces")[0]
				check(packet.lods.size()>=2 and packet.lods[1].size()<packet.index_data.size(),"smaller authored Hover distant level")
			check(found,"Hover far sampling survives preparation")
		print("CAR_SIMPLIFICATION_STOCK ",id," ",data.triangles," triangles; ",data.buffer_bytes," bytes")
		car.free()
		await process_frame
	check(R.meshes.size()<=R.CACHE_LIMIT,"content lookup cache remains bounded")
	print("CAR_SIMPLIFICATION checks=",checks," failures=",failures)
	quit(1 if failures else 0)
