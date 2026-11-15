extends SceneTree
const Policy=preload("res://tests/support/car_iteration_policy.gd")
const WORK: String="res://../build/car-iteration-01-2026-11-15"
const OUT: String="res://../docs/evidence/car-iteration-01-2026-11-15"
var observations: Array=[]
var catalog: Dictionary={}
var active: String=""
var current_car: CarVisual

func _initialize() -> void: run.call_deferred()

func collect(car: CarVisual, parts: Array) -> void:
	for part: MeshInstance3D in parts:
		if part.mesh==null or not part.is_visible_in_tree() or part.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
		var key: String=Policy.code(part.mesh,car.vehicle_id)
		var shaders: Array=[]
		for surface: int in range(part.mesh.get_surface_count()):
			var material: Material=part.get_active_material(surface)
			shaders.append(material.shader.resource_path if material is ShaderMaterial and material.shader!=null else material.get_class() if material!=null else "none")
		observations.append({"vehicle":car.vehicle_id,"mode":active,"key":key,"name":str(part.name),"path":str(car.get_path_to(part)),"triangles":part.mesh.get_faces().size()/3,"shaders":shaders,"blend_shapes":part.mesh.get_blend_shape_count() if part.mesh is ArrayMesh else 0})
		catalog[key]={"source":part.mesh,"vehicle":car.vehicle_id,"name":str(part.name)}

func collect_group(group: Dictionary) -> void:
	preload("res://vehicle/car_detail_reduction.gd").apply_group(group)
	collect(current_car,group.entries.map(func(entry: Dictionary) -> MeshInstance3D: return entry.part))

func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://vehicle/car_detail_reduction.gd").offline=collect_group
	for id: String in Policy.IDS:
		for mode: String in ["stock","fitted"]:
			active=mode
			var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=true;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES: car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			current_car=car
			root.add_child(car)
			while not car.model_ready: await process_frame
			car.free();await process_frame
	var cache:=Resource.new();cache.set_meta("catalog",catalog)
	assert(ResourceSaver.save(cache,WORK.path_join("survey.res"),ResourceSaver.FLAG_COMPRESS)==OK)
	FileAccess.open(OUT.path_join("survey.json"),FileAccess.WRITE).store_string(JSON.stringify(observations,"  "))
	print("ITERATION_SURVEY ",observations.size()," parts; ",catalog.size()," distinct meshes")
	quit()
