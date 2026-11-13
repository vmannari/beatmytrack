extends SceneTree
const Policy=preload("res://vehicle/car_mesh_lods.gd")
var checks: int=0
var failures: int=0
func _initialize()->void:run.call_deferred()
func master(mesh: Mesh)->Array:
	var result: Array=[]
	if mesh is ArrayMesh:
		result=mesh.get("_surfaces").duplicate(true)
		for p: Dictionary in result:p.erase("lods")
	else:
		for index: int in range(mesh.get_surface_count()):result.append(mesh.surface_get_arrays(index))
	return result
func inspect(path: String,id: String,bias: float)->void:
	var scene: PackedScene=load(path);var holder: Node=scene.instantiate();var changed: bool=false
	var policy:=Policy.new()
	for part: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
		if part.mesh==null:continue
		var before: Array=master(part.mesh)
		if part.lod_bias!=bias:part.lod_bias=bias;changed=true
		if not policy.eligible(part,id) and part.mesh is ArrayMesh:
			var levels: int=0
			for packet: Dictionary in part.mesh.get("_surfaces"):levels+=packet.get("lods",[]).size()
			if levels>0:part.mesh=policy.full_detail(part.mesh);changed=true
		checks+=1
		if before!=master(part.mesh):failures+=1;printerr("LOD_POLICY_FAIL master bytes ",path)
	if changed:
		var packed:=PackedScene.new();var error: Error=packed.pack(holder)
		if error==OK:error=ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)
		if error!=OK:failures+=1
	holder.free()
func scan(path: String,id: String,bias: float)->void:
	for file: String in DirAccess.get_files_at(path):
		if file.ends_with(".scn"):inspect(path.path_join(file),id,bias)
	for folder: String in DirAccess.get_directories_at(path):scan(path.path_join(folder),id,bias)
func run()->void:
	for id: String in VehicleCatalog.IDS:
		for simple: bool in [false,true]:
			for edit: String in ["fixed","editable"]:inspect("res://assets/vehicles/modular_car_bases_v1/"+id+("_simple_" if simple else "_full_")+edit+".scn",id,0.5 if simple else 2.0)
			scan("res://assets/vehicles/modular_kits_v1/"+id+("/simple" if simple else "/full"),id,0.5 if simple else 2.0)
		inspect("res://assets/garage/cars_v1/"+id+".scn",id,1.0)
	print("LOD_POLICY ",checks," checks, ",failures," failures");quit(1 if failures else 0)
