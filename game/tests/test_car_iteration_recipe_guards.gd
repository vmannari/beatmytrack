extends SceneTree
const Detail=preload("res://vehicle/car_detail_reduction.gd")
var checks: int=0
var failures: int=0
var injected: bool=false
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;printerr("ITERATION_RECIPE_GUARD_FAIL ",label)
func _initialize() -> void: run.call_deferred()
func inspect(group: Dictionary) -> void:
	var data: Dictionary=Detail.recipe(group.vehicle,group.code)
	print("RECIPE_GROUP ",group.code," entries=",group.entries.size()," recipe=",data.get("parts",{}).size())
	for entry: Dictionary in group.entries:
		var row: Dictionary=data.get("parts",{}).get(entry.code,{})
		if row.is_empty() or row.get("hidden",false): continue
		var mesh: Mesh=Detail.replacement(row,entry.part.mesh)
		check(mesh!=null and not entry.protected and entry.opaque and row.get("source","")==entry.source,"every actual recipe entry validates "+str(entry.part.name))
		if mesh==null or entry.protected or not entry.opaque or row.get("source","")!=entry.source:
			var selected: Mesh=load(Detail.ROOT.path_join(row.mesh))
			print("RECIPE_REJECT ",entry.part.name," protected=",entry.protected," opaque=",entry.opaque," meta=",selected.get_meta("car_detail_source","")," expected=",entry.source," box=",selected.get_aabb()," sourcebox=",entry.part.mesh.get_aabb()," surfaces=",selected.get_surface_count(),"/",entry.part.mesh.get_surface_count())
		if mesh!=null and "_iter01_" in row.mesh and not injected:
			var bad: ArrayMesh=mesh.duplicate();bad.set_meta("car_detail_source","invalid-source")
			Detail.meshes[row.mesh]=bad
			check(Detail.replacement(row,entry.part.mesh)==null,"reject incorrect source provenance")
			var packets: Array=mesh.get("_surfaces").duplicate(true)
			for packet: Dictionary in packets: packet.aabb.position+=Vector3.ONE*0.01
			bad=ArrayMesh.new();bad.set("_surfaces",packets);bad.set_meta("car_detail_source",entry.source)
			Detail.meshes[row.mesh]=bad
			check(Detail.replacement(row,entry.part.mesh)==null,"reject nonmatching exact bounds")
			Detail.meshes[row.mesh]=mesh
			check(Detail.replacement(row,entry.part.mesh)!=null,"restore accepted resource after negative controls")
			injected=true
	Detail.apply_group(group)
func run() -> void:
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Detail.offline=inspect
	var car:=CarVisual.new();car.vehicle_id="forklift";car.cache_rest_pose=false
	root.add_child(car)
	while not car.model_ready: await process_frame
	car.free();check(injected and checks>100,"exercise actual accepted recipes and rejection controls")
	print("ITERATION_RECIPE_GUARDS ",checks," checks, ",failures," failures");quit(1 if failures else 0)
