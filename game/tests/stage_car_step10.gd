extends SceneTree
const Detail=preload("res://vehicle/car_detail_reduction.gd")
const WORK: String="res://../build/car-step10-2026-11-15"
const OUT: String="res://../docs/evidence/car-step10-2026-11-15"
var plan: Dictionary={}
var contexts: Dictionary={}
var changes: Array=[]
var files: Dictionary={}

func _initialize() -> void: run.call_deferred()
func cleaned(candidate: ArrayMesh, bounds: AABB, original: Mesh) -> ArrayMesh:
	var packets: Array=candidate.get("_surfaces").duplicate(true)
	for packet: Dictionary in packets: packet.aabb=bounds
	var result:=ArrayMesh.new();result.set("_surfaces",packets);result.custom_aabb=bounds
	for property: StringName in original.get_meta_list():
		if property not in [&"car_step10_witnesses",&"car_step10_contacts"]: result.set_meta(property,original.get_meta(property))
	return result

func stage(group: Dictionary) -> void:
	for entry: Dictionary in group.entries: entry["original_bounds"]=entry.part.mesh.get_aabb()
	pass # Existing opaque recipes have already run.
	if group.vehicle=="super_rally" or contexts.has(group.code): return
	contexts[group.code]=true
	var recipe: Dictionary={}
	if recipe.is_empty(): recipe={"schema":preload("res://vehicle/car_surface_reduction.gd").SCHEMA,"context":group.code,"parts":{}}
	var count: int=0
	for entry: Dictionary in group.entries:
		var part: MeshInstance3D=entry.part
		if not part.is_visible_in_tree(): continue
		var key: String=group.vehicle+"_"+Detail.mesh_key(part.mesh)
		if not plan.parts.has(key): continue
		if not preload("res://vehicle/car_surface_reduction.gd").permitted(entry):
			print("CAR15_PROTECTED_CONTEXT ",group.vehicle," ",part.name," ",part.mesh.resource_path," protected=",entry.protected," opaque=",entry.opaque)
			continue
		var row: Dictionary=plan.parts[key]
		var candidate: ArrayMesh=load(WORK.path_join("candidates").path_join(row.file))
		assert(candidate.get_meta("car_step10_source","")==key)
		var selected: ArrayMesh=cleaned(candidate,entry.original_bounds,part.mesh)
		selected.set_meta("car_surface_source",entry.source)
		selected.set_meta("car_step10_source",key)
		for surface: int in range(selected.get_surface_count()): selected.surface_set_material(surface,StandardMaterial3D.new())
		var name: String=group.vehicle+"_"+entry.source+"_step10_"+Detail.mesh_key(selected).left(20)+".res"
		assert(ResourceSaver.save(selected,WORK.path_join("staged").path_join(name),ResourceSaver.FLAG_COMPRESS)==OK)
		files[name]="game/assets/vehicles/car_surface_v1/"+name
		recipe.parts[entry.code]={"source":entry.source,"mesh":name,"result":Detail.mesh_key(selected)}
		changes.append({"vehicle":group.vehicle,"context":group.code,"source":key,"part":str(part.name),"before":part.mesh.get_faces().size()/3,"after":selected.get_faces().size()/3})
		count+=1
	if count:
		var name: String=group.vehicle+"_"+group.code+".json"
		FileAccess.open(WORK.path_join("staged").path_join(name),FileAccess.WRITE).store_string(JSON.stringify(recipe,"  "))
		files[name]="game/assets/vehicles/car_surface_v1/"+name

func run() -> void:
	plan=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("selected-plan.json")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("staged")))
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	preload("res://vehicle/car_surface_reduction.gd").offline=stage
	for id: String in ["compact","kart","forklift","electric"]:
		if "--electric-only" in OS.get_cmdline_user_args() and id!="electric":continue
		for editable: bool in [false,true]:
			var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=true;car.editable_kits=editable;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults(id);car.customisation=VehicleCustomisation.defaults()
			root.add_child(car)
			while not car.model_ready: await process_frame
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category,id).slice(1):
						var selection: Dictionary=car.customisation.duplicate();selection[category]=option[0];car.change_kit_parts(selection)
						selection=car.customisation.duplicate();selection[category]="stock";car.change_kit_parts(selection)
			car.free();await process_frame
	preload("res://vehicle/car_surface_reduction.gd").offline=Callable()
	# Hover's existing native race meshes are its source assets. Keep full meshes
	# and producer signatures, and replace only exact selected race resources.
	var observations: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("survey.json")))
	var paths: Dictionary={}
	for row: Dictionary in observations:
		if "--electric-only" not in OS.get_cmdline_user_args() and row.vehicle=="hovercraft" and plan.parts.has(row.key): paths[row.resource]=row.key
	for path: String in paths:
		assert(path.begins_with("res://assets/vehicles/hovercraft_sport_v4/race_") or path.begins_with("res://assets/vehicles/car_coarse_v1/hovercraft_"))
		var key: String=paths[path];var original: ArrayMesh=load(path)
		assert("hovercraft_"+Detail.mesh_key(original)==key)
		var candidate: ArrayMesh=load(WORK.path_join("candidates").path_join(plan.parts[key].file))
		var selected: ArrayMesh=cleaned(candidate,original.get_aabb(),original)
		for surface: int in range(original.get_surface_count()): selected.surface_set_material(surface,original.surface_get_material(surface))
		var name: String="hover_native_"+path.sha256_text().left(24)+".res"
		assert(ResourceSaver.save(selected,WORK.path_join("staged").path_join(name),ResourceSaver.FLAG_COMPRESS)==OK)
		files[name]="game/"+path.trim_prefix("res://")
	FileAccess.open(OUT.path_join("staged.json"),FileAccess.WRITE).store_string(JSON.stringify({"files":files,"contexts":contexts.size(),"changes":changes},"  "))
	print("CAR15_STAGED ",files.size()," files; ",contexts.size()," contexts");quit()
