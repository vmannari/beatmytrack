extends "res://tests/register_volt_smooth_frames.gd"
const WORK: String="res://../build/volt-reflection-smoothing-2026-11-15"
var files: Dictionary={};var replacements: Dictionary={};var migrations: Array=[]
func detail(group: Dictionary) -> void:
	var wanted: bool=false
	for entry: Dictionary in group.entries:
		if targets.has(str(entry.part.name)) or contour(str(entry.part.name)):wanted=true
	if not wanted:D.apply_group(group);return
	var fingerprint: String=key(group,false)
	assert(raw.has(fingerprint),"All unchanged raw members retain the registered identity")
	var data: Dictionary=raw[fingerprint].recipe.duplicate(true)
	if data.is_empty():data={"schema":D.SCHEMA,"parts":{}}
	data.context=group.code
	for entry: Dictionary in group.entries:
		var label: String=str(entry.part.name)
		if not targets.has(label):continue
		assert(not entry.protected and entry.opaque,"Only static opaque paint is authored")
		var mesh: ArrayMesh=load(WORK.path_join("candidates").path_join(label+".res")).duplicate()
		mesh.set_meta("car_detail_source",entry.source)
		assert(mesh.get_aabb()==entry.part.mesh.get_aabb(),"Exact authored bounds")
		var file: String="electric_"+entry.source+"_smooth_"+D.mesh_key(mesh).left(20)+".res"
		assert(ResourceSaver.save(mesh,WORK.path_join("staged").path_join(file),ResourceSaver.FLAG_COMPRESS)==OK)
		files[file]="game/assets/vehicles/car_detail_v1/"+file;replacements[label]={"after":D.mesh_key(mesh),"file":file}
		data.parts[entry.code]={"source":entry.source,"mesh":file};D.meshes[file]=mesh
	var file: String="electric_"+group.code+".json"
	FileAccess.open(WORK.path_join("staged").path_join(file),FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	files[file]="game/assets/vehicles/car_detail_v1/"+file;D.recipes["electric_"+group.code]=data
	migrations.append({"stage":"detail","before":raw[fingerprint].context,"after":group.code})
	D.apply_group(group)
func surface(group: Dictionary) -> void:
	var wanted: bool=false
	for entry: Dictionary in group.entries:
		if targets.has(str(entry.part.name)) or contour(str(entry.part.name)):wanted=true
	if not wanted:S.apply_group(group,D);return
	var fingerprint: String=key(group,true)
	assert(post.has(fingerprint),"All unrelated surface members retain the registered identity")
	var data: Dictionary=post[fingerprint].recipe.duplicate(true);data.context=group.code
	var file: String="electric_"+group.code+".json"
	FileAccess.open(WORK.path_join("staged").path_join("surface_"+file),FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	files["surface_"+file]="game/assets/vehicles/car_surface_v1/"+file
	S.recipes["electric_"+group.code]=data;S.apply_group(group,D)
	migrations.append({"stage":"surface","before":post[fingerprint].context,"after":group.code,"retained_rows":data.parts.size()})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("staged")))
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("frame-registry.json")))
	raw=registry.raw;post=registry.post
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("selected-plan.json"))).parts.values():targets[row.name]=true
	var mesh_builder=preload("res://vehicle/electric_reference_mesh.gd")
	for label: String in JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("contours.json"))).files:
		var row: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("contours.json"))).files[label]
		var mesh: Mesh=load(WORK.path_join("contours").path_join(row.file));mesh_builder.meshes[label]=mesh
		assert(ResourceSaver.save(mesh,WORK.path_join("staged").path_join("contour_"+str(row.file)),ResourceSaver.FLAG_COMPRESS)==OK)
		files["contour_"+str(row.file)]=row.path
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	D.offline=detail;S.offline=surface
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="electric";car.editable_kits=editable;car.cache_rest_pose=false;root.add_child(car)
		while not car.model_ready:await process_frame
		car.free();await process_frame
	FileAccess.open(OUT.path_join("staged.json"),FileAccess.WRITE).store_string(JSON.stringify({"files":files,"replacements":replacements,"migration":migrations},"  "))
	print("VSR_STAGED ",files.size()," Electric-only resources / ",replacements.size()," paint charts");quit()
