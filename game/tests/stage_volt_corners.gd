extends SceneTree
const D=preload("res://vehicle/car_detail_reduction.gd")
const S=preload("res://vehicle/car_surface_reduction.gd")
const WORK: String="res://../build/volt-rear-corners-2026-11-15"
const OUT: String="res://../docs/evidence/volt-rear-corners-2026-11-15"
var registry: Dictionary={};var files: Dictionary={};var contexts: Dictionary={};var migration: Array=[];var replacements: Dictionary={}
func _initialize() -> void: run.call_deferred()
func detail(group: Dictionary) -> void:
	var data: Dictionary=D.recipe(group.vehicle,group.code).duplicate(true);var changed: bool=false
	for entry: Dictionary in group.entries:
		var label: String=str(entry.part.name)
		if not label.begins_with("ReferenceSide"):continue
		assert(data.parts.has(entry.code))
		var prior: Mesh=D.replacement(data.parts[entry.code],entry.part.mesh)
		assert(prior!=null and prior.get_meta("car_keep_master",false))
		var mesh: ArrayMesh=load(WORK.path_join("candidates").path_join(label+".res"))
		assert(mesh.get_meta("car_detail_source")==entry.source and mesh.get_aabb()==entry.part.mesh.get_aabb())
		var file: String="electric_"+entry.source+"_rear_corners_"+D.mesh_key(mesh).left(20)+".res"
		assert(ResourceSaver.save(mesh,WORK.path_join("staged").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		files[file]="game/assets/vehicles/car_detail_v1/"+file
		replacements[label]={'before':D.mesh_key(prior),'after':D.mesh_key(mesh),'file':file}
		data.parts[entry.code]={"source":entry.source,"mesh":file};D.meshes[file]=mesh;changed=true
	if changed:
		var file: String="electric_"+group.code+".json"
		FileAccess.open(WORK.path_join("staged").path_join(file),FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
		files[file]="game/assets/vehicles/car_detail_v1/"+file;D.recipes["electric_"+group.code]=data
	D.apply_group(group)
func surface(group: Dictionary) -> void:
	var others: Array=[];var has_side: bool=false
	for entry: Dictionary in group.entries:
		if str(entry.part.name).begins_with("ReferenceSide"):has_side=true
		else:others.append(entry.code)
	if not has_side:S.apply_group(group,D);return
	others.sort();var key: String=var_to_bytes(others).hex_encode().sha256_text()
	assert(registry.has(key),"Every non-side frame member remains exact")
	var previous: Dictionary=registry[key];var data: Dictionary=previous.recipe.duplicate(true);data.context=group.code
	var file: String="electric_"+group.code+".json"
	FileAccess.open(WORK.path_join("staged").path_join(file),FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	files[file]="game/assets/vehicles/car_surface_v1/"+file
	contexts[group.code]=true;migration.append({"old_context":previous.context,"new_context":group.code,"unchanged_rows":data.parts.size()})
	S.recipes["electric_"+group.code]=data;S.apply_group(group,D)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("staged")))
	registry=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("frame-registry.json")))
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	D.offline=detail;S.offline=surface
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="electric";car.editable_kits=editable;car.cache_rest_pose=false
		root.add_child(car)
		while not car.model_ready:await process_frame
		car.free();await process_frame
	# Metadata-only backing identity changes preserve every contour GPU stream.
	var contours: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/car_step10_volt.json"))
	for row: Dictionary in contours:
		var path: String="res://assets/vehicles/electric_rear_lamp_gaps_v1/"+str(row.file)
		var old: ArrayMesh=load(path);var mesh: ArrayMesh=old.duplicate()
		var side: String="ReferenceSide-1_0" if "-1.0" in str(row.name) else "ReferenceSide1_0"
		mesh.set_meta("volt_contour_backing",replacements[side].after)
		assert(D.mesh_key(old)==D.mesh_key(mesh))
		var file: String="contour_"+str(row.file)
		assert(ResourceSaver.save(mesh,WORK.path_join("staged").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		files[file]="game/"+path.trim_prefix("res://")
	FileAccess.open(OUT.path_join("staged.json"),FileAccess.WRITE).store_string(JSON.stringify({"files":files,"replacements":replacements,"migration":migration},"  "))
	print("VOLT_CORNER_STAGED ",files.size()," files; ",contexts.size()," exact surface frames");quit()
