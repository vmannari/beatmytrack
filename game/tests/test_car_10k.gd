extends "res://tests/test_car_simplification.gd"
## C10K02: source-piece attribute proof, protected articulation and all kits.
const Budget=preload("res://vehicle/car_budget_reduction.gd")
var OUTPUT: String=OS.get_environment("BMT_CAR_BUDGET_OUT") if OS.has_environment("BMT_CAR_BUDGET_OUT") else "res://../docs/evidence/car-10k-models-2026-11-14"
var WORK: String=OS.get_environment("BMT_CAR_BUDGET_WORK") if OS.has_environment("BMT_CAR_BUDGET_WORK") else "res://../build/car-10k-models-2026-11-14"
var verified: int=0
var stock_rows: Array=[]

func _initialize() -> void: verify.call_deferred()
func packed(source: Mesh) -> ArrayMesh:
	if source is ArrayMesh: return source
	var packets: Array=[]
	for surface: int in range(source.get_surface_count()): packets.append(RenderingServer.mesh_get_surface(source.get_rid(),surface))
	var result:=ArrayMesh.new();result.set("_surfaces",packets);result.custom_aabb=source.get_aabb()
	return result

func verify_parts(car: CarVisual,parts: Array) -> void:
	for part: MeshInstance3D in parts:
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		if Budget.is_protected(part): continue
		if part.mesh is ArrayMesh and part.mesh.get_blend_shape_count()>0:
			check(part.mesh.get_blend_shape_count()==10,"ten original moving Kart poses retained")
			continue
		var key: String=Budget.code(part.mesh,car.vehicle_id)
		var directory: String=WORK.path_join("staged-final-five") if "--candidates" in OS.get_cmdline_user_args() else Budget.ROOT
		var path: String=directory.path_join(key+".res")
		if not ResourceLoader.exists(path): continue
		var source: ArrayMesh=packed(part.mesh)
		var result: ArrayMesh=load(path)
		check(result.get_meta("car_budget_source","")==key,"exact source-key guard")
		check(result.get_surface_count()==part.mesh.get_surface_count() and result.get_aabb()==part.mesh.get_aabb(),"surface slots and actual source culling bounds retained "+key)
		for surface: int in range(source.get_surface_count()):
			var all: Dictionary=vertex_codes(source,surface,false)
			var selected: Dictionary=vertex_codes(result,surface,true)
			var exact: bool=true
			for entry: PackedByteArray in selected: exact=exact and all.has(entry)
			check(exact,"every retained encoded vertex attribute matches its source")
		var finishes: Array=[]
		for surface: int in range(source.get_surface_count()): finishes.append(part.get_active_material(surface))
		Budget.swap(part,result)
		for surface: int in range(finishes.size()): check(part.get_active_material(surface)==finishes[surface],"active instance finish retained")
		verified+=1

func verify() -> void:
	Base.enabled=false;Kits.enabled=false;Cache.enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	Budget.offline=verify_parts
	for id: String in VehicleCatalog.IDS:
		if id=="super_rally": continue
		var counts: Array=[]
		for editable: bool in [false,true]:
			var car:=CarVisual.new();car.vehicle_id=id;car.editable_kits=editable;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id)
			root.add_child(car)
			while not car.model_ready: await process_frame
			var stock: Dictionary=inventory(car,false);counts.append(stock.triangles)
			check(stock.triangles>=9000 and stock.triangles<=11000,"stock model is around 10000 triangles "+id)
			stock_rows.append({"vehicle":id,"editable":editable,"triangles":stock.triangles,"surfaces":stock.surfaces})
			if editable and "--stock-only" not in OS.get_cmdline_user_args():
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category,id):
						var value: Dictionary=car.customisation.duplicate();value[category]=option[0];car.change_kit_parts(value)
					var value: Dictionary=car.customisation.duplicate();value[category]="stock";car.change_kit_parts(value)
				# The pre-existing Hover stock replacement differs from initial stock.
				if id!="hovercraft": check(inventory(car,false).triangles==stock.triangles,"all module swaps restore exact stock count "+id)
			car.free();await process_frame
		check(counts[0]==counts[1],"fixed and editable stock geometry agrees "+id)
	check(verified>100,"actual reduced source pieces checked")
	FileAccess.open(OUTPUT.path_join("source-proof.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"verified_parts":verified,"rows":stock_rows},"  "))
	print("TEN_K_SOURCE ",checks," checks, ",failures," failures; pieces=",verified)
	quit(1 if failures else 0)
