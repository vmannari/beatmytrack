extends "res://tests/register_volt_hood_outline.gd"
const WORK: String="res://../build/volt-hood-outline-2026-11-16"
var files: Dictionary={};var migrations: Array=[]
func wanted(group: Dictionary) -> bool:
	for entry: Dictionary in group.entries:
		if str(entry.part.name)=="SportBonnetShutLine":return true
	return false
func detail(group: Dictionary) -> void:
	if not wanted(group):D.apply_group(group);return
	var fingerprint: String=key(group,false)
	assert(raw.has(fingerprint),"All non-bonnet-line raw members remain exact")
	var data: Dictionary=raw[fingerprint].recipe.duplicate(true);data.context=group.code
	var file: String="electric_"+group.code+".json"
	FileAccess.open(WORK.path_join("staged").path_join(file),FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	files[file]="game/assets/vehicles/car_detail_v1/"+file;D.recipes["electric_"+group.code]=data
	migrations.append({"stage":"detail","before":raw[fingerprint].context,"after":group.code,"rows":data.parts.size()})
	D.apply_group(group)
func surface(group: Dictionary) -> void:
	if not wanted(group):S.apply_group(group,D);return
	var fingerprint: String=key(group,true)
	assert(post.has(fingerprint),"All non-bonnet-line surface members remain exact")
	var data: Dictionary=post[fingerprint].recipe.duplicate(true);data.context=group.code
	var file: String="electric_"+group.code+".json"
	FileAccess.open(WORK.path_join("staged").path_join("surface_"+file),FileAccess.WRITE).store_string(JSON.stringify(data,"  "))
	files["surface_"+file]="game/assets/vehicles/car_surface_v1/"+file;S.recipes["electric_"+group.code]=data
	migrations.append({"stage":"surface","before":post[fingerprint].context,"after":group.code,"rows":data.parts.size()})
	S.apply_group(group,D)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(WORK.path_join("staged")))
	var registry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OUT.path_join("frame-registry.json")))
	raw=registry.raw;post=registry.post;targets["SportBonnetShutLine"]=true
	preload("res://vehicle/modular_car_base.gd").enabled=false;preload("res://vehicle/modular_car_kits.gd").enabled=false;preload("res://vehicle/prepared_car_cache.gd").enabled=false
	D.offline=detail;S.offline=surface
	for editable: bool in [false,true]:
		var car:=CarVisual.new();car.vehicle_id="electric";car.editable_kits=editable;car.cache_rest_pose=false;root.add_child(car)
		while not car.model_ready:await process_frame
		car.free();await process_frame
	FileAccess.open(OUT.path_join("staged.json"),FileAccess.WRITE).store_string(JSON.stringify({"files":files,"migrations":migrations},"  "))
	print("VHO_MIGRATION ",files.size()," exact frame recipes; every reduction row retained");quit()
