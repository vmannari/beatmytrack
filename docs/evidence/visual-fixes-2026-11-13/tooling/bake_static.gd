extends SceneTree
const R = preload("res://vehicle/car_static_reduction.gd")
const Base = preload("res://vehicle/modular_car_base.gd")
const Kits = preload("res://vehicle/modular_car_kits.gd")
const Cache = preload("res://vehicle/prepared_car_cache.gd")
const OUT = "res://../docs/evidence/visual-fixes-2026-11-13"
var baker = preload("res://tests/support/car_static_reduction_bake.gd").new()

func _initialize() -> void: run.call_deferred()

func car_for(id: String, editable: bool, batch: bool = true) -> CarVisual:
	var car := CarVisual.new()
	car.vehicle_id=id
	car.simple_model=true
	car.editable_kits=editable
	car.batch_parts=batch
	car.cache_rest_pose=false
	car.livery=VehicleLivery.defaults(id)
	car.customisation=VehicleCustomisation.defaults()
	return car

func hover_far(editable: bool) -> void:
	R.enabled=false
	var near_car: CarVisual = car_for("hovercraft",editable)
	root.add_child(near_car)
	while not near_car.model_ready: await process_frame
	var far_car: CarVisual = car_for("hovercraft",editable,false)
	root.add_child(far_car)
	while not far_car.model_ready: await process_frame
	for part: MeshInstance3D in far_car.find_children("*","MeshInstance3D",true,false):
		if str(part.name).begins_with("SportSkirtSeam"): part.mesh=baker.half_seam(part.mesh)
	await VisualGeometry.batch_static_parts(far_car)
	await VisualGeometry.batch_car_parts(far_car)
	Cache._stable_names(near_car)
	Cache._stable_names(far_car)
	var reductions: int = 0
	for part: MeshInstance3D in near_car.find_children("*","MeshInstance3D",true,false):
		if not part.mesh is ArrayMesh or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var other: MeshInstance3D = far_car.get_node_or_null(near_car.get_path_to(part))
		assert(other!=null,"Far model must retain every attachment")
		if other.mesh.get_faces().size()==part.mesh.get_faces().size(): continue
		var result: ArrayMesh = preload("res://rendering/mesh_vertex_packing.gd").with_detail(part.mesh,other.mesh,0.005)
		assert(result!=part.mesh,"Hover far sampling must be installed")
		result.set_meta("car_authored_far",true)
		baker.publish(part.mesh,result,"hovercraft")
		reductions+=1
	assert(reductions>0)
	near_car.free()
	far_car.free()
	R.enabled=true

func run() -> void:
	Base.enabled=false
	Kits.enabled=false
	Cache.enabled=false
	preload("res://ui/garage_car_cache.gd").enabled=false
	R.offline=baker.create
	for id: String in ["compact","kart","electric"]:
		for editable: bool in [false,true]:
			var car: CarVisual = car_for(id,editable)
			root.add_child(car)
			while not car.model_ready: await process_frame
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category,id):
						var choices: Dictionary = car.customisation.duplicate()
						choices[category]=option[0]
						car.change_kit_parts(choices)
					var choices: Dictionary = car.customisation.duplicate()
					choices[category]="stock"
					car.change_kit_parts(choices)
			car.free()
			await process_frame
		print("CAR_STATIC_BAKE ",id)
	R.offline=Callable()
	for editable: bool in [false,true]: await hover_far(editable)
	FileAccess.open(OUT+"/static-bake.json",FileAccess.WRITE).store_string(JSON.stringify({"resources":baker.observations},"\t"))
	print("CAR_STATIC_BAKE resources=",baker.observations.size())
	quit()
