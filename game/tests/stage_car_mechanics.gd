extends "res://tests/register_car_mechanics_driver.gd"
const WORK: String="res://../build/car-mechanics-2026-11-17"
var plan: Dictionary={}
var files: Dictionary={}
var changes: Array=[]
var baselines: Dictionary={}
var moving: ArrayMesh
func clean(candidate: ArrayMesh,original: Mesh) -> ArrayMesh:
	var packets: Array=candidate.get("_surfaces").duplicate(true)
	for packet: Dictionary in packets:packet.aabb=original.get_aabb()
	var result:=ArrayMesh.new();result.set("_surfaces",packets);result.custom_aabb=original.get_aabb()
	for property: StringName in original.get_meta_list():
		if "witness" not in property and "contact" not in property:result.set_meta(property,original.get_meta(property))
	return result
func ancestor(part: Node) -> CarVisual:
	while part!=null and not part is CarVisual:part=part.get_parent()
	return part as CarVisual
func has_driver(group: Dictionary) -> bool:
	for entry: Dictionary in group.entries:
		if str(entry.part.name)=="TomkartDriver":return true
	return false
func detail(group: Dictionary) -> void:
	if group.vehicle!="kart" or not has_driver(group):D.apply_group(group);return
	var car: CarVisual=ancestor(group.entries[0].part)
	for entry: Dictionary in group.entries:
		if str(entry.part.name)=="TomkartDriver":entry.part.mesh=moving
	var updated: Dictionary={}
	for candidate: Dictionary in D.groups(car):
		if has_driver(candidate):updated=candidate;break
	assert(not updated.is_empty(),"Actual driver articulation frame remains available")
	var fingerprint: String=key(updated,false)
	assert(raw.has(fingerprint),"Index-only driver retains every other raw member")
	var recipe: Dictionary=raw[fingerprint].recipe.duplicate(true);recipe.context=updated.code
	var name: String="kart_"+updated.code+".json"
	FileAccess.open(WORK.path_join("staged").path_join("detail_"+name),FileAccess.WRITE).store_string(JSON.stringify(recipe,"  "))
	files["detail_"+name]="game/assets/vehicles/car_detail_v1/"+name
	D.recipes["kart_"+updated.code]=recipe;D.apply_group(updated)
func surface(group: Dictionary) -> void:
	var frame_key: String=group.vehicle+"_"+group.code
	if not baselines.has(frame_key):
		var path: String=S.ROOT.path_join(frame_key+".json")
		var recipe: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {"schema":S.SCHEMA,"context":group.code,"parts":{}}
		if group.vehicle=="kart" and has_driver(group):
			var fingerprint: String=key(group,true)
			assert(post.has(fingerprint),"Driver retains every other post-detail member")
			recipe=post[fingerprint].recipe.duplicate(true);recipe.context=group.code
		baselines[frame_key]=recipe.duplicate(true)
	var original_recipe: Dictionary=baselines[frame_key].duplicate(true)
	S.recipes[frame_key]=original_recipe
	S.apply_group(group,D)
	var recipe: Dictionary=original_recipe.duplicate(true)
	var count: int=0
	var bindings: Dictionary={}
	for entry: Dictionary in group.entries:
		if entry.opaque and entry.part.is_visible_in_tree():
			var code: String=group.vehicle+"_"+D.mesh_key(entry.part.mesh)
			bindings[var_to_bytes([code,entry.pose]).hex_encode().sha256_text()]=true
	for entry: Dictionary in group.entries:
		var part: MeshInstance3D=entry.part
		if not part.is_visible_in_tree():continue
		var source_key: String=group.vehicle+"_"+D.mesh_key(part.mesh)
		if not plan.parts.has(source_key):source_key=part.mesh.get_meta("car_pass10_source",source_key)
		if not plan.parts.has(source_key):continue
		assert(S.permitted(entry),"Every chosen member retains its original material/articulation policy")
		var row: Dictionary=plan.parts[source_key]
		var covered: bool=true
		for binding: String in row.get("required_bindings",[]):
			if not bindings.has(binding):covered=false;break
		if not covered:continue
		var candidate: ArrayMesh=load(WORK.path_join("candidates").path_join(row.file))
		assert(candidate.get_meta("car_pass10_source","")==source_key)
		var selected: ArrayMesh=clean(candidate,part.mesh)
		selected.set_meta("car_surface_source",entry.source)
		selected.set_meta("car_pass10_source",source_key)
		for at: int in range(selected.get_surface_count()):selected.surface_set_material(at,StandardMaterial3D.new())
		var name: String=group.vehicle+"_"+entry.source+"_pass10_"+D.mesh_key(selected).left(20)+".res"
		assert(ResourceSaver.save(selected,WORK.path_join("staged").path_join(name),ResourceSaver.FLAG_COMPRESS)==OK)
		files[name]="game/assets/vehicles/car_surface_v1/"+name
		recipe.parts[entry.code]={"source":entry.source,"mesh":name,"result":D.mesh_key(selected)}
		changes.append({"vehicle":group.vehicle,"context":group.code,"source":source_key,"part":str(part.name),"before":part.mesh.get_faces().size()/3,"after":selected.get_faces().size()/3})
		preload("res://vehicle/car_budget_reduction.gd").swap(part,selected)
		count+=1
	if count or (group.vehicle=="kart" and has_driver(group)):
		var name: String=frame_key+".json"
		FileAccess.open(WORK.path_join("staged").path_join(name),FileAccess.WRITE).store_string(JSON.stringify(recipe,"  "))
		files[name]="game/assets/vehicles/car_surface_v1/"+name
func run() -> void:
	plan=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("selected-plan.json")))
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("driver-frame-registry.json")))
	raw=registry.raw;post=registry.post;targets["TomkartDriver"]=true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("staged")))
	moving=load(WORK.path_join("candidates").path_join(plan.driver.file))
	var original: ArrayMesh=load("res://"+str(plan.driver.source_path).trim_prefix("game/"))
	assert(moving.get_blend_shape_count()==original.get_blend_shape_count() and moving.blend_shape_mode==original.blend_shape_mode)
	var proof=load("res://tests/bake_car_mechanics_candidates.gd").new()
	for sf: int in range(original.get_surface_count()):
		for pose: int in range(-1,original.get_blend_shape_count()):
			assert(proof.corner(original,sf,pose)==proof.corner(moving,sf,pose),"Exact rendered driver corner and pose bytes")
	proof.free()
	assert(ResourceSaver.save(moving,WORK.path_join("staged/driver_steering.res"),ResourceSaver.FLAG_COMPRESS)==OK)
	files["driver_steering.res"]=plan.driver.source_path
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	D.offline=detail;S.offline=surface
	for id: String in ["compact","kart","forklift"]:
		for editable: bool in [false,true]:
			var car:=CarVisual.new();car.vehicle_id=id;car.simple_model=true;car.editable_kits=editable;car.cache_rest_pose=false;root.add_child(car)
			while not car.model_ready:await process_frame
			if editable:
				for category: String in VehicleCustomisation.CATEGORIES:
					for option: Array in VehicleCustomisation.options(category,id).slice(1):
						var choice: Dictionary=car.customisation.duplicate();choice[category]=option[0];car.change_kit_parts(choice)
						choice=car.customisation.duplicate();choice[category]="stock";car.change_kit_parts(choice)
			car.free();await process_frame
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("survey.json"))):
		if row.vehicle!="hovercraft" or not plan.parts.has(row.key):continue
		var path: String=row.resource
		assert(path.begins_with("res://assets/vehicles/hovercraft_sport_v4/race_") or path.begins_with("res://assets/vehicles/car_coarse_v1/hovercraft_"),"Hover uses a racing-only native resource")
		var source: ArrayMesh=load(path);assert("hovercraft_"+D.mesh_key(source)==row.key)
		var candidate: ArrayMesh=load(WORK.path_join("candidates").path_join(plan.parts[row.key].file))
		var selected: ArrayMesh=clean(candidate,source)
		selected.set_meta("car_pass10_source",row.key)
		for at: int in range(source.get_surface_count()):selected.surface_set_material(at,source.surface_get_material(at))
		var name: String="hover_"+path.sha256_text().left(24)+".res"
		assert(ResourceSaver.save(selected,WORK.path_join("staged").path_join(name),ResourceSaver.FLAG_COMPRESS)==OK)
		files[name]="game/"+path.trim_prefix("res://")
	FileAccess.open(OUT.path_join("staged.json"),FileAccess.WRITE).store_string(JSON.stringify({"files":files,"changes":changes},"  "))
	print("CP3_STAGED ",files.size()," authored resources; ",changes.size()," actual member replacements");quit()
