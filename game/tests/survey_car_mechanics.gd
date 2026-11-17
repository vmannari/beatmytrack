extends "res://tests/survey_car_pass10.gd"
const MECH_WORK: String="res://../build/car-mechanics-2026-11-17"
const MECH_OUT: String="res://../docs/evidence/car-mechanics-2026-11-17"
var bodies: Dictionary={}
func observe(car: CarVisual,holders: Variant) -> void:
	var first: int=rows.size()
	super.observe(car,holders)
	for at: int in range(first,rows.size()):
		var row: Dictionary=rows[at]
		if bodies.has(row.key):continue
		var mesh: Mesh=catalog[row.key].source
		var surfaces: Array=[]
		for sf: int in range(mesh.get_surface_count()):
			var a: Array=mesh.surface_get_arrays(sf)
			var points: Array=[];var normals: Array=[]
			for p: Vector3 in a[Mesh.ARRAY_VERTEX]:points.append([p.x,p.y,p.z])
			for p: Vector3 in a[Mesh.ARRAY_NORMAL]:normals.append([p.x,p.y,p.z])
			var indices: Array=[]
			if a[Mesh.ARRAY_INDEX]!=null:indices.assign(a[Mesh.ARRAY_INDEX])
			else:
				for index: int in range(points.size()):indices.append(index)
			surfaces.append({"vertices":points,"normals":normals,"indices":indices})
		bodies[row.key]={"name":row.name,"resource":row.resource,"surfaces":surfaces}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MECH_WORK))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MECH_OUT))
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Source.observer=observe
	for id: String in ["compact","kart","forklift","hovercraft"]:
		for current: String in ["stock","fitted"]:
			mode=current
			var car=Source.new();car.vehicle_id=id;car.simple_model=true;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.customisation=VehicleCustomisation.defaults()
			if mode=="fitted":
				for category: String in VehicleCustomisation.CATEGORIES:car.customisation[category]=VehicleCustomisation.options(category,id)[-1][0]
			root.add_child(car)
			while not car.model_ready:await process_frame
			car.free();await process_frame
	var cache:=Resource.new();cache.set_meta("catalog",catalog)
	assert(ResourceSaver.save(cache,MECH_WORK.path_join("survey.res"),ResourceSaver.FLAG_COMPRESS)==OK)
	FileAccess.open(MECH_WORK.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(bodies))
	FileAccess.open(MECH_OUT.path_join("survey.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	print("MECHANICS_SURVEY ",rows.size()," parts / ",catalog.size()," meshes");quit()
