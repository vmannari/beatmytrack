extends SceneTree
## Exact raw full/simple meshes for fast source-guarded module fallback.
const K=preload("res://vehicle/electric_kits.gd")
const M=preload("res://vehicle/electric_reference_mesh.gd")

func _initialize() -> void: run.call_deferred()
func run() -> void:
	M.use_baked=false
	M.meshes.clear()
	var car:=CarVisual.new()
	car.simple_model = false # Offline source geometry.
	car.vehicle_id="electric"
	car.paint_materials={"body":CompactFinish.paint(Color("b8bbb9"))}
	for simple: bool in [false,true]:
		car.simple_model=simple
		for option: Array in VehicleCustomisation.options("hood","electric").slice(1):
			var frame:=Node3D.new()
			K.hood(car,frame,str(option[0]))
			frame.free()
	car.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(K.HOOD_MESH_ROOT))
	var entries: Array=[]
	var total_bytes:=0
	for key: String in M.meshes:
		var path: String=K.HOOD_MESH_ROOT.path_join(key.sha256_text().left(24)+".res")
		var error: Error=ResourceSaver.save(M.meshes[key],path,ResourceSaver.FLAG_COMPRESS)
		if error!=OK: push_error("Cannot save "+key); quit(1); return
		var bytes: int=FileAccess.get_file_as_bytes(path).size()
		total_bytes+=bytes
		entries.append({"key":key,"file":path.get_file(),"bytes":bytes,"arrays_sha256":var_to_bytes(M.meshes[key].surface_get_arrays(0)).hex_encode().sha256_text()})
	var sources: Dictionary={}
	for file: String in K.HOOD_MESH_SOURCES: sources[file]=FileAccess.get_sha256("res://vehicle/"+file)
	var manifest: Dictionary={"revision":K.HOOD_REVISION,"hood_ids":K.hood_option_ids(),"engine":Engine.get_version_info().string,"sources":sources,"meshes":entries,"total_bytes":total_bytes}
	FileAccess.open(K.HOOD_MESH_ROOT.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t")+"\n")
	print("VOLT_HOOD_MESH_BAKE: ",entries.size()," meshes, ",total_bytes," bytes")
	quit(0 if entries.size()==62 else 1)
