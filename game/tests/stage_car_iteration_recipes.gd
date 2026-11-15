extends SceneTree
## CI01: merge reviewed components into the existing complete-frame recipes.
## Production construction is unchanged; old enclosure/zero-area removals stay.
const Detail=preload("res://vehicle/car_detail_reduction.gd")
const Policy=preload("res://tests/support/car_iteration_policy.gd")
const WORK: String="res://../build/car-iteration-01-2026-11-15"
const OUT: String="res://../docs/evidence/car-iteration-01-2026-11-15"
var plan: Dictionary={}
var contexts: Dictionary={}
var changes: Array=[]

func _initialize() -> void: run.call_deferred()

func stage(group: Dictionary) -> void:
	for entry: Dictionary in group.entries: entry["original_bounds"]=entry.part.mesh.get_aabb()
	Detail.apply_group(group)
	if group.vehicle!="forklift" or contexts.has(group.code): return
	contexts[group.code]=true
	var recipe: Dictionary=Detail.recipe(group.vehicle,group.code).duplicate(true)
	if recipe.is_empty(): recipe={"schema":Detail.SCHEMA,"context":group.code,"parts":{}}
	var count: int=0
	for entry: Dictionary in group.entries:
		var part: MeshInstance3D=entry.part
		if not part.is_visible_in_tree(): continue
		var key: String=Policy.code(part.mesh,group.vehicle)
		if not plan.parts.has(key): continue
		assert(not entry.protected and entry.opaque)
		var candidate: ArrayMesh=load(WORK.path_join("candidates").path_join(key+".res"))
		var packets: Array=candidate.get("_surfaces").duplicate(true)
		for packet: Dictionary in packets: packet.aabb=entry.original_bounds
		var selected:=ArrayMesh.new();selected.set("_surfaces",packets);selected.custom_aabb=entry.original_bounds
		for property: StringName in candidate.get_meta_list(): selected.set_meta(property,candidate.get_meta(property))
		assert(selected.get_meta("car_iteration_source","")==key)
		selected.set_meta("car_detail_source",entry.source)
		for surface: int in range(selected.get_surface_count()): selected.surface_set_material(surface,StandardMaterial3D.new())
		var name: String="forklift_"+entry.source+"_iter01_"+Detail.mesh_key(selected).left(20)+".res"
		assert(ResourceSaver.save(selected,WORK.path_join("recipes").path_join(name),ResourceSaver.FLAG_COMPRESS)==OK)
		recipe.parts[entry.code]={"source":entry.source,"mesh":name}
		changes.append({"context":group.code,"part":str(part.name),"source":entry.source,"candidate":key,"before":part.mesh.get_faces().size()/3,"after":selected.get_faces().size()/3,"file":name,"maximum_scale":maxf(entry.pose.basis.get_scale().abs().x,maxf(entry.pose.basis.get_scale().abs().y,entry.pose.basis.get_scale().abs().z))})
		count+=1
	if count:
		FileAccess.open(WORK.path_join("recipes").path_join("forklift_"+group.code+".json"),FileAccess.WRITE).store_string(JSON.stringify(recipe,"  "))

func run() -> void:
	plan=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("candidate-plan.json")))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("recipes")))
	preload("res://vehicle/modular_car_base.gd").enabled=false
	preload("res://vehicle/modular_car_kits.gd").enabled=false
	preload("res://vehicle/prepared_car_cache.gd").enabled=false
	Detail.offline=stage
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="forklift";car.simple_model=true;car.editable_kits=editable;car.cache_rest_pose=false;car.livery=VehicleLivery.defaults("forklift");car.customisation=VehicleCustomisation.defaults()
		root.add_child(car)
		while not car.model_ready: await process_frame
		if editable:
			for category: String in VehicleCustomisation.CATEGORIES:
				for option: Array in VehicleCustomisation.options(category,"forklift").slice(1):
					var selection: Dictionary=car.customisation.duplicate();selection[category]=option[0];car.change_kit_parts(selection)
					selection=car.customisation.duplicate();selection[category]="stock";car.change_kit_parts(selection)
		car.free();await process_frame
	Detail.offline=Callable()
	FileAccess.open(OUT.path_join("staged-recipes.json"),FileAccess.WRITE).store_string(JSON.stringify({"contexts":contexts.size(),"changes":changes},"  "))
	print("ITERATION_RECIPES ",contexts.size()," contexts; ",changes.size()," changes")
	quit()
