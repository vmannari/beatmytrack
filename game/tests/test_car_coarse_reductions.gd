extends "res://tests/test_car_simplification.gd"
const Coarse = preload("res://vehicle/car_coarse_reduction.gd")
var coarse_rows: Array = []

func _initialize() -> void: coarse_verify.call_deferred()

func verify_coarse(part: MeshInstance3D, car: CarVisual) -> Mesh:
	var source: ArrayMesh=part.mesh
	var result: ArrayMesh=Coarse.resolve(source,car.vehicle_id)
	if result==source: return source
	check(result.get_surface_count()==source.get_surface_count(),"coarse material slots "+car.vehicle_id)
	check(result.get_aabb()==source.get_aabb(),"coarse exact culling bounds "+car.vehicle_id)
	for surface: int in range(source.get_surface_count()):
		var originals: Dictionary=vertex_codes(source,surface,false)
		var retained: Dictionary=vertex_codes(result,surface,true)
		var exact: bool=true
		for code: PackedByteArray in retained: exact=exact and originals.has(code)
		check(exact,"coarse retained encoded attributes "+car.vehicle_id+str(part.name))
	return result

func make_coarse_car(id: String, coarse: bool, editable: bool) -> CarVisual:
	Coarse.enabled=coarse
	var car := CarVisual.new()
	car.vehicle_id=id
	car.editable_kits=editable
	car.cache_rest_pose=false
	car.livery=VehicleLivery.defaults(id)
	root.add_child(car)
	while not car.model_ready: await process_frame
	return car

func coarse_verify() -> void:
	Base.enabled=false
	Kits.enabled=false
	Cache.enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	Coarse.offline=verify_coarse
	for id: String in VehicleCatalog.IDS:
		var counts: Array=[]
		for editable: bool in [false,true]:
			var old: CarVisual=await make_coarse_car(id,false,editable)
			var old_data: Dictionary=inventory(old,false)
			old.free()
			var car: CarVisual=await make_coarse_car(id,true,editable)
			var data: Dictionary=inventory(car,false)
			check(data.triangles<old_data.triangles,"coarse production reduction "+id)
			check(data.surfaces==old_data.surfaces,"coarse no new visible surfaces "+id)
			counts.append(data.triangles)
			if id=="kart":
				var driver: MeshInstance3D=car.find_child("TomkartDriver",true,false)
				check(driver.mesh.get_blend_shape_count()==10,"moving driver ten poses retained")
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					var parts: Dictionary=car.customisation.duplicate()
					parts[category]=VehicleCustomisation.options(category,id)[-1][0]
					car.change_kit_parts(parts)
				check(inventory(car,false).triangles>0,"coarse fitted assembly "+id)
			coarse_rows.append({"vehicle":id,"editable":editable,"before":old_data.triangles,"after":data.triangles,"bytes":data.buffer_bytes})
			car.free()
			await process_frame
		check(counts[0]==counts[1],"fixed/editable stock geometry count "+id)
	check(Coarse.meshes.size()<=Coarse.LIMIT,"coarse lookup cache bounded")
	Coarse.offline=Callable()
	var out: String="res://../docs/evidence/car-coarse-models-2026-11-14/source-verification.json"
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":coarse_rows},"\t"))
	print("COARSE_SOURCE ",checks," checks, ",failures," failures")
	quit(1 if failures else 0)
