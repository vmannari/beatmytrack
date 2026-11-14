extends SceneTree
## Read the stored assemblies directly; this does not prewarm the App benchmark.
const OUT: String="res://../docs/evidence/car-loading-improvements-2026-11-13/"
func _initialize() -> void: run.call_deferred()
func payload(mesh: Mesh) -> int:
	var bytes: int=0
	for surface: int in range(mesh.get_surface_count()):
		var packet: Dictionary=mesh.get("_surfaces")[surface] if mesh is ArrayMesh else RenderingServer.mesh_get_surface(mesh.get_rid(),surface)
		for field: String in ["vertex_data","attribute_data","skin_data","index_data","blend_shapes"]: bytes+=packet.get(field,PackedByteArray()).size()
		var lods: Array=packet.get("lods",[])
		for at: int in range(1,lods.size(),2): bytes+=lods[at].size()
	return bytes
func dependencies(path: String, result: Dictionary) -> void:
	if result.has(path): return
	result[path]=FileAccess.get_file_as_bytes(path).size()
	for declaration: String in ResourceLoader.get_dependencies(path):
		var file: String=declaration.split("::")[-1]
		if file.begins_with("res://") and FileAccess.file_exists(file): dependencies(file,result)
func run() -> void:
	var phase: String="after"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase=arg.trim_prefix("--phase=")
	var rows: Array=[]
	for id: String in ["compact","kart","forklift","electric","hovercraft"]:
		for quality: String in ["simple","full"]:
			for mode: String in ["fixed","editable"]:
				var path: String="res://assets/vehicles/modular_car_bases_v1/"+id+"_"+quality+"_"+mode+".scn"
				var scene: PackedScene=ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
				assert(scene!=null)
				var holder: Node=scene.instantiate()
				var meshes: Dictionary={}
				var bytes: int=0
				var surfaces: int=0
				var triangles: int=0
				for node: MeshInstance3D in holder.find_children("*","MeshInstance3D",true,false):
					if node.mesh==null: continue
					if not meshes.has(node.mesh): bytes+=payload(node.mesh); meshes[node.mesh]=true
					if node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY: continue
					surfaces+=node.mesh.get_surface_count()
					triangles+=node.mesh.get_faces().size()/3
				var deps: Dictionary={}
				dependencies(path,deps)
				var stored: int=0
				for size: int in deps.values(): stored+=size
				rows.append({"id":id,"quality":quality,"mode":mode,"raw_bytes":bytes,"unique_meshes":meshes.size(),"surfaces":surfaces,"triangles":triangles,"disk_dependency_bytes":stored,"dependencies":deps})
				holder.free()
	FileAccess.open(OUT+phase+"-assets.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"\t"))
	print("CAR_LOADING_ASSET_METRICS ",rows.size()," assemblies")
	quit()
