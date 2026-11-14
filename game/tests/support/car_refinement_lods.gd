extends "res://vehicle/car_mesh_lods.gd"
## Preserve inherited LOD policy; isolate embedded identities when publishing.
var previous: Dictionary = {}
var reused: int = 0

func policy() -> String:
	return FileAccess.get_sha256("res://vehicle/car_mesh_lods.gd")+FileAccess.get_sha256("res://tests/support/car_refinement_lods.gd")

func master_key(mesh: ArrayMesh) -> String:
	var packets: Array=mesh.get("_surfaces").duplicate(true)
	for packet: Dictionary in packets:
		packet.erase("material");packet.erase("lods")
	return var_to_bytes([mesh.custom_aabb,packets]).hex_encode().sha256_text()

func remember(path: String) -> void:
	# Read the previous output before overwriting it. Only encoded-identical
	# masters under the same engine and LOD policy may reuse their index levels.
	previous.clear()
	if not ResourceLoader.exists(path): return
	var scene: PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if scene==null: return
	var holder: Node=scene.instantiate()
	var data: Dictionary={}
	for name: String in ["modular_car_base","modular_kit","garage_rest"]:
		if holder.has_meta(name): data=holder.get_meta(name)
	var version: Dictionary=Engine.get_version_info()
	var key: Array=data.get("key",[])
	var same_engine: bool=version.string in key or [str(version.string),str(version.get("hash",""))] in key
	var same_policy: bool=holder.get_meta("car_lod_policy","")==policy()
	# Explicit migration of this pass's already validated, unstamped outputs.
	if "--reuse-validated-lods" in OS.get_cmdline_user_args():
		same_policy=same_policy or data.get("sources",{}).get("game/vehicle/car_mesh_lods.gd","")==FileAccess.get_sha256("res://vehicle/car_mesh_lods.gd")
	if same_engine and same_policy:
		var bytes: int=0
		for node: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
			if not node.mesh is ArrayMesh or node.mesh.get_blend_shape_count()>0: continue
			var code: String=master_key(node.mesh)
			if previous.has(code): continue
			var levels: Array=[]
			var size: int=0
			for packet: Dictionary in node.mesh.get("_surfaces"):
				var lods: Array=packet.get("lods",[])
				levels.append(lods)
				for at: int in range(1,lods.size(),2): size+=lods[at].size()
			if size>0 and bytes+size<=32*1024*1024: previous[code]=levels;bytes+=size
	holder.free()

func prepare(source: Mesh) -> Mesh:
	# Splitting invariant suit faces removes morph storage, not visible detail.
	# The original animated suit had no generated distance levels.
	if source.has_meta("kart_split_source_sha256"): return source
	if source is ArrayMesh and source.get_blend_shape_count()==0 and not source.has_meta("car_authored_far"):
		var code: String=master_key(source)
		if previous.has(code):
			var packets: Array=source.get("_surfaces").duplicate(true)
			for surface: int in range(packets.size()):
				if not previous[code][surface].is_empty(): packets[surface].lods=previous[code][surface]
			var result := ArrayMesh.new()
			result.set("_surfaces",packets)
			result.custom_aabb=source.custom_aabb;result.shadow_mesh=source.shadow_mesh
			for surface: int in range(source.get_surface_count()): assert(result.surface_get_arrays(surface)==source.surface_get_arrays(surface))
			reused+=1
			return result
	return super.prepare(source)

func bake(path: String, vehicle: String = "", bias: float = 1.0) -> Error:
	if vehicle.is_empty() and path.get_file().get_basename() in VehicleCatalog.IDS: vehicle = path.get_file().get_basename()
	var scene: PackedScene = ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if scene==null: return ERR_CANT_OPEN
	var holder: Node = scene.instantiate()
	prepare_vehicle(holder,vehicle,bias)
	holder.set_meta("car_lod_policy",policy())
	if vehicle in ["compact","forklift"]: preload("res://tests/support/car_model_buffers.gd").detach(holder)
	var packed := PackedScene.new()
	var error: Error = packed.pack(holder)
	if error==OK: error = ResourceSaver.save(packed,path,ResourceSaver.FLAG_COMPRESS)
	holder.free()
	print("CAR_LOD_REUSE ",path," exact_masters=",reused)
	return error
